# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache 2.0 License.

from enum import Enum
import infra.proc
import infra.proposal
import infra.crypto
import infra.clients
import http
import os
import base64
import json

from loguru import logger as LOG


class MemberEndpointException(Exception):
    def __init__(self, response, *args, **kwargs):
        super(MemberEndpointException, self).__init__(*args, **kwargs)
        self.response = response


class NoRecoveryShareFound(MemberEndpointException):
    pass


class UnauthenticatedMember(MemberEndpointException):
    """Member is not known by the service"""


class AckException(MemberEndpointException):
    pass


class MemberStatus(Enum):
    ACCEPTED = "Accepted"
    ACTIVE = "Active"


class MemberAPI:
    class Preview_v1:
        API_VERSION = infra.clients.API_VERSION_PREVIEW_01

        @classmethod
        def propose(cls, member, remote_node, proposal):
            with remote_node.api_versioned_client(
                *member.auth(write=True),
                api_version=cls.API_VERSION,
            ) as mc:
                r = mc.post("/gov/members/proposals:create", proposal)
                if r.status_code != http.HTTPStatus.OK.value:
                    raise infra.proposal.ProposalNotCreated(r)

                return infra.proposal.Proposal(
                    proposer_id=member.local_id,
                    proposal_id=r.body.json()["proposalId"],
                    state=infra.proposal.ProposalState(r.body.json()["proposalState"]),
                    view=r.view,
                    seqno=r.seqno,
                )

        @classmethod
        def vote(cls, member, remote_node, proposal, ballot):
            with remote_node.api_versioned_client(
                *member.auth(write=True),
                api_version=cls.API_VERSION,
            ) as mc:
                r = mc.post(
                    f"/gov/members/proposals/{proposal.proposal_id}/ballots/{member.service_id}:submit",
                    body=ballot,
                )
                return r

        @classmethod
        def withdraw(cls, member, remote_node, proposal):
            with remote_node.api_versioned_client(
                *member.auth(write=True),
                api_version=cls.API_VERSION,
            ) as mc:
                r = mc.post(f"/gov/members/proposals/{proposal.proposal_id}:withdraw")
                if (
                    r.status_code == http.HTTPStatus.OK.value
                    and r.body.json()["proposalState"] == "Withdrawn"
                ):
                    proposal.state = infra.proposal.ProposalState.WITHDRAWN
                return r

        @classmethod
        def update_ack_state_digest(cls, member, remote_node):
            with remote_node.api_versioned_client(
                *member.auth(write=True),
                api_version=cls.API_VERSION,
            ) as mc:
                return mc.post(f"/gov/members/state-digests/{member.service_id}:update")

        @classmethod
        def ack(cls, member, remote_node, state_digest):
            with remote_node.api_versioned_client(
                *member.auth(write=True),
                api_version=cls.API_VERSION,
            ) as mc:
                r = mc.post(
                    f"/gov/members/state-digests/{member.service_id}:ack",
                    body=state_digest,
                )
                if r.status_code == http.HTTPStatus.UNAUTHORIZED:
                    raise UnauthenticatedMember(
                        f"Failed to ack member {member.local_id}: {r.status_code}"
                    )
                assert r.status_code == http.HTTPStatus.NO_CONTENT, r
                member.status = MemberStatus.ACTIVE
                return r

        @classmethod
        def get_recovery_share(cls, member, remote_node):
            with remote_node.api_versioned_client(
                api_version=cls.API_VERSION,
            ) as mc:
                r = mc.get(f"/gov/recovery/encrypted-shares/{member.service_id}")
                if r.status_code != http.HTTPStatus.OK.value:
                    raise NoRecoveryShareFound(r)
                return r.body.json()["encryptedShare"]

    class Classic:
        API_VERSION = infra.clients.API_VERSION_CLASSIC

        @classmethod
        def propose(cls, member, remote_node, proposal):
            with remote_node.client(*member.auth(write=True)) as mc:
                r = mc.post("/gov/proposals", proposal)
                if r.status_code != http.HTTPStatus.OK.value:
                    raise infra.proposal.ProposalNotCreated(r)

                return infra.proposal.Proposal(
                    proposer_id=member.local_id,
                    proposal_id=r.body.json()["proposal_id"],
                    state=infra.proposal.ProposalState(r.body.json()["state"]),
                    view=r.view,
                    seqno=r.seqno,
                )

        @classmethod
        def vote(cls, member, remote_node, proposal, ballot):
            with remote_node.client(*member.auth(write=True)) as mc:
                r = mc.post(
                    f"/gov/proposals/{proposal.proposal_id}/ballots",
                    body=ballot,
                )
                return r

        @classmethod
        def withdraw(cls, member, remote_node, proposal):
            with remote_node.client(*member.auth(write=True)) as c:
                r = c.post(f"/gov/proposals/{proposal.proposal_id}/withdraw")
                if (
                    r.status_code == http.HTTPStatus.OK.value
                    and r.body.json()["state"] == "Withdrawn"
                ):
                    proposal.state = infra.proposal.ProposalState.WITHDRAWN
                return r

        @classmethod
        def update_ack_state_digest(cls, member, remote_node):
            with remote_node.client(*member.auth()) as mc:
                return mc.post("/gov/ack/update_state_digest")

        @classmethod
        def ack(cls, member, remote_node, state_digest):
            with remote_node.client(*member.auth(write=True)) as mc:
                r = mc.post("/gov/ack", body=state_digest)
                if r.status_code == http.HTTPStatus.UNAUTHORIZED:
                    raise UnauthenticatedMember(
                        f"Failed to ack member {member.local_id}: {r.status_code}"
                    )
                assert r.status_code == http.HTTPStatus.NO_CONTENT, r
                member.status = MemberStatus.ACTIVE
                return r

        @classmethod
        def get_recovery_share(cls, member, remote_node):
            with remote_node.client() as mc:
                r = mc.get(f"/gov/encrypted_recovery_share/{member.service_id}")
                if r.status_code != http.HTTPStatus.OK.value:
                    raise NoRecoveryShareFound(r)
                return r.body.json()["encrypted_share"]


class Member:
    def __init__(
        self,
        local_id,
        curve,
        common_dir,
        share_script,
        is_recovery_member=True,
        key_generator=None,
        member_data=None,
        authenticate_session=True,
        gov_api_impl=None,
    ):
        self.common_dir = common_dir
        self.local_id = local_id
        self.status = MemberStatus.ACCEPTED
        self.share_script = share_script
        self.member_data = member_data
        self.is_recovery_member = is_recovery_member
        self.is_retired = False
        self.authenticate_session = authenticate_session
        assert self.authenticate_session == "COSE", self.authenticate_session
        self.gov_api_impl = gov_api_impl

        self.member_info = {}
        self.member_info["certificate_file"] = f"{self.local_id}_cert.pem"
        self.member_info["encryption_public_key_file"] = (
            f"{self.local_id}_enc_pubk.pem" if is_recovery_member else None
        )
        self.member_info["data_json_file"] = (
            f"{self.local_id}_data.json" if member_data else None
        )

        if key_generator is not None:
            key_generator_args = [
                "--name",
                self.local_id,
                "--curve",
                f"{curve.name}",
            ]

            if is_recovery_member:
                key_generator_args += [
                    "--gen-enc-key",
                ]

            infra.proc.ccall(
                key_generator,
                *key_generator_args,
                path=self.common_dir,
                log_output=False,
            ).check_returncode()
        else:
            # If no key generator is passed in, the identity of the member
            # should have been created in advance (e.g. by a previous network)
            assert os.path.isfile(
                os.path.join(self.common_dir, f"{self.local_id}_privk.pem")
            )
            assert os.path.isfile(
                os.path.join(self.common_dir, self.member_info["certificate_file"])
            )

        if self.member_data is not None:
            with open(
                os.path.join(self.common_dir, self.member_info["data_json_file"]),
                "w",
                encoding="utf-8",
            ) as md:
                json.dump(member_data, md)

        with open(
            os.path.join(self.common_dir, self.member_info["certificate_file"]),
            encoding="utf-8",
        ) as c:
            self.cert = c.read()
            self.service_id = infra.crypto.compute_cert_der_hash_hex_from_pem(self.cert)

        LOG.info(f"Member {self.local_id} created: {self.service_id}")

    def auth(self, write=False):
        if self.authenticate_session == "COSE":
            return (None, None, self.local_id)
        if self.authenticate_session:
            if write:
                return (self.local_id, self.local_id)
            else:
                return (self.local_id, None)
        else:
            return (None, self.local_id)

    def is_active(self):
        return self.status == MemberStatus.ACTIVE and not self.is_retired

    def set_active(self):
        # Use this with caution (i.e. only when the network is opening)
        self.status = MemberStatus.ACTIVE

    def set_retired(self):
        # Members should be marked as retired once they have been removed
        # from the service
        self.is_retired = True

    def propose(self, remote_node, proposal):
        infra.clients.get_clock().advance()
        return self.gov_api_impl.propose(self, remote_node, proposal)

    def vote(self, remote_node, proposal, ballot):
        return self.gov_api_impl.vote(self, remote_node, proposal, ballot)

    def withdraw(self, remote_node, proposal):
        return self.gov_api_impl.withdraw(self, remote_node, proposal)

    def update_ack_state_digest(self, remote_node):
        r = self.gov_api_impl.update_ack_state_digest(self, remote_node)
        if r.status_code == http.HTTPStatus.UNAUTHORIZED:
            raise UnauthenticatedMember(
                f"Failed to ack member {self.local_id}: {r.status_code}"
            )
        if r.status_code != http.HTTPStatus.OK:
            raise AckException(r, f"Failed to ack member {self.local_id}")
        return r.body.json()

    def ack(self, remote_node):
        return self.gov_api_impl.ack(
            self, remote_node, self.update_ack_state_digest(remote_node)
        )

    def get_and_decrypt_recovery_share(self, remote_node):
        if not self.is_recovery_member:
            raise ValueError(f"Member {self.local_id} does not have a recovery share")

        share = self.gov_api_impl.get_recovery_share(self, remote_node)

        with open(
            os.path.join(self.common_dir, f"{self.local_id}_enc_privk.pem"),
            "r",
            encoding="utf-8",
        ) as priv_enc_key:
            return infra.crypto.unwrap_key_rsa_oaep(
                base64.b64decode(share),
                priv_enc_key.read(),
            )

    def get_and_submit_recovery_share(self, remote_node):
        if not self.is_recovery_member:
            raise ValueError(f"Member {self.local_id} does not have a recovery share")

        help_res = infra.proc.ccall(self.share_script, "--help", log_output=False)
        help_res.check_returncode()
        help_out = help_res.stdout.decode()
        supports_api_version = "--api-version" in help_out

        cmd = [
            self.share_script,
            f"https://{remote_node.get_public_rpc_host()}:{remote_node.get_public_rpc_port()}",
            "--member-enc-privk",
            os.path.join(self.common_dir, f"{self.local_id}_enc_privk.pem"),
        ]

        if supports_api_version:
            cmd += [
                "--api-version",
                self.gov_api_impl.API_VERSION,
            ]

        cmd += [
            "--cert",
            os.path.join(self.common_dir, f"{self.local_id}_cert.pem"),
            "--key",
            os.path.join(self.common_dir, f"{self.local_id}_privk.pem"),
            "--cacert",
            os.path.join(self.common_dir, "service_cert.pem"),
        ]
        res = infra.proc.ccall(
            *cmd,
            log_output=True,
            env=os.environ,
        )
        res.check_returncode()
        return infra.clients.Response.from_raw(res.stdout)
