require(ggplot2)
require(dplyr)

df <- (read.csv(header = TRUE, sep = "#", file = "./RLCoverageccfraft_S5.csv"))

# Add a column to df that combines the three columns Spec, P, and C.
df$Group <- paste(df$Mode, df$View, sep = "_")

# Eyeball if all configurations are roughly equally represented.
df %>% group_by(Group) %>% summarize(count = n())

# Print configurations where leaders retire.
df %>% 
  group_by(Group, state) %>% 
  summarize(count = n()) %>% 
  filter(state == "RetiredLeader")

# Count the occurrences of each character sequence in column state
# grouped by column Group.
df %>%
  group_by(Group, state) %>%
  summarize(count = n()) %>%
  ggplot(aes(x=Group, fill=state, y=count)) +
    geom_bar(stat="identity") +
    theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=0.5))

######################

require(tidyr)

actions <- read.csv(header = TRUE, sep = "#", file = "./RLCoverageccfraft_actions.csv")
actions$Group <- paste(actions$Mode, actions$View, sep = "_")

acts <- actions %>%
  group_by(Group, Mode, View) %>%
  summarise_all(mean) %>%
  pivot_longer(cols=6:23, names_to = "Action", values_to = "Mean") %>%
  ggplot(aes(x=Group, fill=Action, y=Mean)) +
  geom_bar(stat="identity") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

###### 

trials <- actions %>%
  ggplot(aes(x = Id, y = Trials, color=Group)) +
  geom_point()

require(gridExtra)
grid.arrange(acts, trials, ncol=2)
