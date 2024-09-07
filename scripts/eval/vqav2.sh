#!/bin/bash
CKPT=$1
NAME=$2

gpu_list="${CUDA_VISIBLE_DEVICES:-0}"
IFS=',' read -ra GPULIST <<< "$gpu_list"

CHUNKS=${#GPULIST[@]}

SPLIT="llava_vqav2_mscoco_test-dev2015"
LOCAL_ANSWER_DIR="./playground/data/eval_local_files/vqav2"

for IDX in $(seq 0 $((CHUNKS-1))); do
    CUDA_VISIBLE_DEVICES=${GPULIST[$IDX]} python -m eagle.eval.model_vqa_loader \
        --model-path $CKPT \
        --question-file ./playground/data/eval/vqav2/$SPLIT.jsonl \
        --image-folder ./playground/data/eval/vqav2/test2015 \
        --answers-file ${LOCAL_ANSWER_DIR}/$SPLIT/$NAME/${CHUNKS}_${IDX}.jsonl \
        --num-chunks $CHUNKS \
        --chunk-idx $IDX \
        --temperature 0 \
        --conv-mode vicuna_v1 &
done

wait

output_file=${LOCAL_ANSWER_DIR}/$SPLIT/$NAME/merge.jsonl

# Clear out the output file if it exists.
> "$output_file"

# Loop through the indices and concatenate each file.
for IDX in $(seq 0 $((CHUNKS-1))); do
    cat ${LOCAL_ANSWER_DIR}/$SPLIT/$NAME/${CHUNKS}_${IDX}.jsonl >> "$output_file"
done

python scripts/convert_vqav2_for_submission.py --src ${LOCAL_ANSWER_DIR}/$SPLIT/$NAME/merge.jsonl --save_path ${LOCAL_ANSWER_DIR}/$SPLIT/$NAME/vqav2-upload-$NAME.json --split $SPLIT --ckpt $NAME