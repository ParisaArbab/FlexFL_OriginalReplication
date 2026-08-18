# Note
Evaluation needs to execute postprocessing process, which requires buggy programs in `/FlexFL/data/input/buggy_program`.
However, the whole folder consumes 4.5G and thus is deleted from this reproduction package.
Please follow instructions in `/prepare/buggy_program` to obtain complete information if you want to reproduce our work from the scratch.

# Quickly evaluate results provided to reproduce performance shown in RQ1 and RQ4
```bash
python eval.py --dataset Defects4J --stage LR --bug_list All    # RQ1.1 FlexFL
python eval_FL.py --dataset Defects4J --fl BoostN               # RQ1.1 BoostN
python eval_FL.py --dataset Defects4J --fl Ochiai               # RQ1.1 Ochiai
python eval_FL.py --dataset Defects4J --fl SBIR                 # RQ1.1 SBIR

python eval.py --dataset Defects4J --stage LR --bug_list AutoFL # RQ1.2 FlexFL

python eval_FL.py --dataset GHRB --fl BoostN                    # RQ4   BoostN
python eval.py --dataset GHRB --stage SR                        # RQ4   Agent4SR
python eval.py --dataset GHRB --stage LR                        # RQ4   FlexFL
```

# Reproduce our work of FlexFL
1. Download Llama3-8B-Instruct (https://llama.meta.com/llama-downloads/). 
Or use other open-source/closed-source LLMs you like. Update `# Construction of open-source model` part in pipeline.py to adapt to LLMs you use.
2. Reproduce results from scratch. (see `run.sh` which is based on Llama3-8B-Instruct)
Main Arguments of `pipeline.py` of FlexFL:
(a) dataset : Defects4J or GHRB
(b) input : `bug_report` for only use bug reports, `trigger_test` for only use trigger tests, `All` for use whatever available.
(c) stage : `SR` for the first stage, `LR` for the second stage