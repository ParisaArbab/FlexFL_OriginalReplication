cat "./bug_list.txt" | while read bug
do
    project=${bug%-*}
    bugid=${bug#*-}
    echo $project-$bugid
    rm -rf ./repos/$bug
    mkdir ./repos/$bug
    rm -rf ./res/$bug
    mkdir ./res/$bug
    bash computeSBFL.sh $project $bugid
done