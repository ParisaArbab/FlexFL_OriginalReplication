import os
from csv import DictReader, DictWriter
    
with open('./bug_list.txt') as f:
    bugs = [e.strip() for e in f.readlines()]

for bug in bugs:
    with open(f"../../buggy_program/methods_buggy_Defects4j/{bug}.corpusMappingMethodLevelGranularity") as f:
        methods = [e.strip() for e in f.readlines()]
    print(bug)
    with open(f"./res/{bug}/ochiai.ranking.csv") as f:
        sbfl_rank = [e.strip().split(';')[0] for e in f.readlines()[1:]]
    
    rank = []
    for row in sbfl_rank:
        line = int(row.split(':')[1])
        method = row.split(':')[0]
        class_name, method_signature = method.split('#')
        file = class_name.split('$')[0]
        classes = class_name.split('$')[1:]
        while classes[-1].isdigit():
            classes = classes[:-1]
        flag = True
        for method in methods:
                start_line = int(method.split('.')[-2])
                end_line = int(method.split('.')[-1])
                function = '.'.join(method.split('.')[:-2])
                class_name = function[:function.find('(')]
                class_name = class_name[:class_name.rfind('.')]
                method_name = function[len(class_name)+1:]
                if class_name == file + '.' + '.'.join(classes) and start_line <= line and end_line >= line:
                    rank.append({
                        "File" : class_name,
                        "Signature" : method_name,
                        "StartLine" : start_line,
                        "EndLine" : end_line
                    })
                    flag = False
                    break
        if flag and '<clinit>' not in row and '$'.join(classes) != method_signature.split('(')[0]:
            print(bug, row)
    if len(rank) == 0:
        print(bug)
        continue
    with open(f'./ochiai_results/{bug}_method-susps.csv', 'w') as f:
        writer = DictWriter(f, fieldnames=rank[0].keys())
        writer.writeheader()
        for row in rank:
            writer.writerow(row)
