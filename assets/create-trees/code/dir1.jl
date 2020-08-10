# This file was generated, do not modify it. # hide
t = maketree("mydir"=>[])

for i=1:3
    for j=1:2
        global t = touch(t, "$i/$j/data.csv"; value=rand(10))
    end
end
t