# This file was generated, do not modify it. # hide
df1 = mv(dfs, r".*yellow.csv$", s"yellow.csv", combine=vcat)
df2 = mv(df1, r".*green.csv$", s"green.csv", combine=vcat)