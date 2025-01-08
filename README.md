# 1. my_soc
my soc rv32I prj from github Ai ------ copilot

Example Scenario
Let's say you have a GitHub repository named my_soc under your GitHub username hankonly.

Step-by-Step Instructions
1. Locate Your Repository URL:Go to your GitHub profile: GitHub. Navigate to your repository my_soc.
2. Copy the URL from your browser's address bar. It should look something like this: https://github.com/hankonly/my_soc.

3. Provide the URL in Your Message:
When you want me to access or help you with something in your repository, include the URL in your message.
Example Message 
Here is an example of how you could provide the repository URL in your message:
User:
> "Hi, I need help with my project. Here is the repository URL: https://github.com/hankonly/my_soc. Can you check the xx.v file and help me with it?"

4. By providing the URL, I can directly refer to your repository and assist you with specific files or issues you have.Feel free to try it out, and let me know how I can help you with your my_soc project!

## 1.1. plan
|version|feature|done| verifie|note|
|-------|-------|-|-|---------|
|v0.01|1. 5stage rv32i|y|-|Insert bubble to hazard|
|v0.01|2. ahb bus|y|-|-|
|v0.01|3. ahb-2-apb bridge|y|-|-|
|v0.02|code review to problme resoled|y|-|-|
|v0.03|verify by simulation|n|-|-|
|v0.04|forward |n|-|-|
|v0.05|brach-prediction|n|-|-|
|v0.06|exception & intr|n|-|-|

## 1.2. version
### 1.2.1. v0.01 base arch
- basic soc
  - core 
    - 5-stage-pipiline rv32i core
    - i/d cache
    - jtag & cpu_debug
    - hazard detect & handle
  - ahb
    - master
      - core
      - dma 
    - slave 
      - sram
      - rom
      - ahb-to-apb bridge
        - uart 
### 1.2.2. v0.02 code review
1. 检查 remove ex_enable,  just remain decode_enable_out
2. 检查 if i-cache miss, if-stage 会尝试访问 ahb 总线， 
    - 删除 if-stage 里面的ahb访问，它应该等待cache 完成 ahb访问; 然后从cache取; 
    - 否则的话会出现总线冲突，降低效率 or 死锁。
    - d-cache 存在相同的问题
      - update : memory_enable_out set to 0 & wait for d-cache 
1. 检查 me-stage, 当 cache miss 的时候，必须 stall，否则接下来的指令会导致 mem flush.
    - 新增一个 mem_stall , src : mem_stage, dst: rv32i , Or-ed with other stall source 
      - if-stage，if i-cache miss 是否需要stall ? 不需要，因为if 阶段会自动让下一个 stage halt;
      - 这里就是 if / me stage 的差别了, me stage 是需要告知前面的 stage 等待它, 而 if 已经有机制控制后面的stage wait
      - 3 个 stall 的需求，实现是否相同 ----------------？
3. 检查 i/d cache, 将2者的主要存储器件，修改为 sram
    - 新建一个 sram module, 和 ahb_sram 不同，这个sram 是cpu内部的。

## 1.3. remark
### 1.3.1. note
1. ai 也会出错，记得每次跟新了之后，先手动比较，再update

### 1.3.2. store & restore the work
"Hi, I need help with my project. Here is the repository URL: https://github.com/hankonly/my_soc. Can you check the xxx/yyy.v file and help me with it?"

### 1.3.3. check:
贪婪一点: 
check the interface between core/rv32i_core.v and all other file like core/*.v for me. if no error found, don't print .v file

check all module Instantiate in file core/rv32i_core.v, is it constant with these module defined ?

不行的话，就一个一个的来尝试把:
check the interface between main rv32i_core.v file and the individual stage files (stage1_if.v, stage2_id.v, stage3_ex.v, stage4_me.v, stage5_wb.v) for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & ALU.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & ControlUnit.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & ImmediateGenerator.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & regfile.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & i-cache.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & d-cache.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & jtag.v for me, if no error found,just tell me , don't print .v file
check the interface between rv32i_core.v & cpu_debug.v for me, if no error found,just tell me , don't print .v file

check the interface between top.v & rv32i_core.v for me, if no error found,just tell me , don't print .v file
check the interface between top.v & rom.v for me, if no error found,just tell me , don't print .v file
check the interface between top.v & sram.v for me, if no error found,just tell me , don't print .v file
check the interface between top.v & ahb.v for me, if no error found,just tell me , don't print .v file
check the interface between top.v & dma.v for me, if no error found,just tell me , don't print .v file


### 1.3.4. add detail
add detail to finish module ALUControlUnit;
add detail to finish module RegisterFile;

