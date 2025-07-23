\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])

   //Makerfile test program to check all RV32-I instructions
   m4_test_prog()


\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   //Program counter(just increments as of now)
   $next_pc[31:0] = $reset ? 0 :
                    $taken_br == 0 ? >>1$next_pc[31:0] + 4 :
                    $br_tgt_pc;
   $pc[31:0] = >>1$next_pc;
   
   //IMem implementation - Instructions are being loaded by m4_asm automatically
   //Read is always enabled
   `READONLY_MEM($pc , $$instr[31:0])
   
   //Instruction Decode
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   $is_i_instr = $instr[6:2] == 5'b00000 ||
                 $instr[6:2] == 5'b00001 ||
                 $instr[6:2] == 5'b00100 ||
                 $instr[6:2] == 5'b00110 ||
                 $instr[6:2] == 5'b11001;
   $is_r_instr = $instr[6:2] == 5'b01011 ||
                 $instr[6:2] == 5'b01100 ||
                 $instr[6:2] == 5'b10110;
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   //Extract fields - opcode,rs1,rs2 etc. as per RISC-V base instruction formats
   $opcode[6:0] = $instr[6:0];
   $rd[4:0] = $instr[11:7];
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}},$instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}},$instr[30:25],$instr[11:7] } :
                $is_b_instr ? { {20{$instr[31]}},$instr[7],$instr[30:25],$instr[11:8],$instr[8] } :
                $is_u_instr ? { $instr[31:12] , {12{$instr[12]}} } :
                $is_j_instr ? { {12{$instr[31]}},$instr[19:12],$instr[20],$instr[30:21],$instr[21] }: 
                32'b0 ; //Default
   
   //Check which fields are valid for the current instruction
   $rd_valid = $is_r_instr || $is_i_instr ||
               $is_u_instr || $is_j_instr;
   $funct3_valid = $is_r_instr || $is_i_instr ||
                   $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr ||
                $is_s_instr || $is_b_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $imm_valid = $is_j_instr || $is_i_instr ||
                $is_s_instr || $is_b_instr ||
                $is_u_instr;
   
   //Decode exact instruction
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits == 11'b0_000_0110011;
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_slti = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits == 11'b0_001_0010011;
   $is_srli = $dec_bits == 11'b0_101_0010011;
   $is_srai = $dec_bits == 11'b1_101_0010011;
   $is_sub = $dec_bits == 11'b1_000_0110011;
   $is_sll = $dec_bits == 11'b0_001_0110011;
   $is_slt = $dec_bits == 11'b0_010_0110011;
   $is_sltu = $dec_bits == 11'b0_011_0110011;
   $is_xor = $dec_bits == 11'b0_100_0110011;
   $is_srl = $dec_bits == 11'b0_101_0110011;
   $is_sra = $dec_bits == 11'b1_101_0110011;
   $is_or = $dec_bits == 11'b0_110_0110011;
   $is_and = $dec_bits == 11'b0_111_0110011;
   $is_load = $dec_bits ==? 11'bx_xxx_0000011; //Considering all load instructions under 1
   
   //ALU
   $result[31:0] = $is_addi ? $src1_value + $imm :    //ADD immediate
                   $is_add ? $src1_value + $src2_value :    //ADD
                   $is_andi ? $src1_value & $imm :    //AND immediate
                   $is_ori ? $src1_value | $imm :    //OR immediate
                   $is_xori ? $src1_value ^ $imm :    //XOR immediate
                   $is_slli ? $src1_value << $imm[5:0] :    //Shift left logical immediate
                   $is_srli ? $src1_value >> $imm[5:0] :    //Shift right logical immediate
                   $is_and ? $src1_value & $src2_value:    //AND
                   $is_or ? $src1_value | $src2_value:    //OR
                   $is_xor ? $src1_value ^ $src2_value:    //XOR
                   $is_sub ? $src1_value - $src2_value:    //SUB
                   $is_sll ? $src1_value << $src2_value[4:0]:    //Shift left logical
                   $is_srl ? $src1_value >> $src2_value[4:0]:    //Shift right logical
                   $is_sltu ? $sltu_rslt:    //Set if less than,unsigned
                   $is_sltiu ? $sltiu_rslt:    //Set if less than,unsigned immediate
                   $is_lui ? {$src1_value[31:12] , 12'b0} :    //Load upper immediate (Combined with ori to load 32 bits register)
                   $is_auipc ? $pc + $imm :    //Add Upper Immediate to PC. Same as $br_tgt_pc implemented earlier
                   $is_jal ?  $pc + 32'd4 :    //Jump-and-Link
                   $is_jalr ? $pc + 32'd4 :    //Jump-and-Link register (will need to change)
                   $is_slt ? (($src1_value[31] != $src2_value[31]) ?
                   {31'b0, $src1_value[31]} : $sltu_rslt) :    //Set if less than, signed
                   $is_slti ? (($src1_value[31] != $imm[31]) ?
                   {31'b0, $src1_value[31]} : $sltiu_rslt) :    //Set if less than, signed immediate
                   $is_sra ? $sra_rslt[31:0] :    //Shift right arithmetic
                   $is_srai ? $srai_rslt[31:0] :    //Shift right arithmetic immediate
                   32'b0;  //Default
   $wr_data[31:0] = $rd == 5'b0 ? 32'b0 :      //Keep x0 as 'always zero'
                    $rd_valid ? $result : 32'b0;
   
   //SLTU and SLTI (set if less than, unsigned) results:
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   
   //SRA and SRAI (shift right, arithmetic) results:
   // sign extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}} , $src1_value };
   // 64 bit sign extended results which we will truncate and take in $results
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   
   
   
   //Branch Logic
   $taken_br = ($src1_value == $src2_value) && $is_beq ? 1'b1 : 
               ($src1_value != $src2_value) && $is_bne ? 1'b1 : 
               (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) && $is_blt ? 1'b1:
               (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) && $is_bge ? 1'b1:
               ($src1_value < $src2_value) && $is_bltu ? 1'b1: 
               ($src1_value >= $src2_value) && $is_bgeu ? 1'b1: 
               1'b0;
   $br_tgt_pc[31:0] = $pc + $imm;
   
   //Log clean-up for dangling signals
   `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $funct3 $funct3_valid
              $opcode $imm_valid $instr $rs2 $rs2_valid $imm
              $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu
              $is_addi $is_add);
   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   //Register File macro
   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $wr_data[31:0], $rs1_valid, $rs1[4:0], $src1_value, $rs2_valid, $rs2[4:0], $src2_value)
   
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule