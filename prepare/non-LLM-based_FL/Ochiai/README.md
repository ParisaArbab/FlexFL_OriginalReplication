# Description
- compute_All_bug.sh : Compute the method-level ochiai results of bugs in the `bug_list.txt`
- computeSBFL.sh     : Compute the method-level ochiai results of one bug.
- utils.sh           : Utils for computeSBFL.sh
- filter_ochiai.py   : Match results in `res` to actual methods in the buggy program, results in `ochiai_results`

# Run
1. update bug_list.txt
2. bash compute_All_bug.sh
3. python filter_ochiai.py (Before you do this step, ensure that you have obtained methods via steps in `buggy_program`)