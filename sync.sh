#!/bin/bash
rsync -avz --progress \
    -e "ssh -i ~/.ssh/ssh-key-1774242605040/ssh-key-1774242605040 -o StrictHostKeyChecking=no" \
    --exclude='.env' \
    --exclude='*.tar' \
    --exclude='*.tar.gz' \
    /home/oleg/projects/openclaw-assistant/llms/ \
    oleg@130.193.36.58:~/llms/
