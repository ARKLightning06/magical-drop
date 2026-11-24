################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Andrew Koes, 1012691482
# Student 2: Andrew Li, 1012142441 (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4
# - Unit height in pixels:      4
# - Display width in pixels:    512
# - Display height in pixels:   512
# - Base Address for Display:   0x10004000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10040000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# Game State Specifications

#sleep time
SLEEP_TIME:
    .word 100
# Tick time
TICK_CYCLE:
    .word 3000

# Grid template - Stores 7 x 14 words, each representing the top left corner of one of the bubbles in the grid 
.align 2
GRID_TEMPLATE:
    .space 392
CURRENT_GRID:
    .space 392

# Grid specifications
GRID_HORIZONTAL_OFFSET:
    .word 96
GRID_WIDTH:
    .word 224
COLUMN_WIDTH:
    .word 32
GRID_HEIGHT:
    .word 57344

# Player specifications (set in initialize_fool)
PLAYER_1_BOUND_LEFT:
  .word 0
PLAYER_1_BOUND_RIGHT:
  .word 0

# Colors
BACKGROUND_COLOR:
  .word 0x1C0333

BORDER_COLOR:
  .word 0x71797E

COLOR_RED:
  .word 0xFF2A54
COLOR_BLUE:
  .word 0x1E90FF
COLOR_GREEN:
  .word 0x1CE858
COLOR_YELLOW:
  .word 0xFFD500
COLOR_SHEEN:
  .word 0xFFFDF5
  
COLOR_ARROW:
  .word 0xFFFDF5

CLOWN_COLOR_RED:
  .word 0x00E61C3D
CLOWN_COLOR_GREEN:
  .word 0x000B6E3B
CLOWN_COLOR_GOLD:
  .word 0x00FFC400
CLOWN_COLOR_FACE:
  .word 0x00FAFAFA

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################

  # SAVED REGISTERS 
  # s0 = CHACACTER_POS_2
  # s1 = BUBBLES_HELD_1
  # s2 = CHARACTER_POS_1
  # s3 = BUBBLES_HELD_2
  # s4 = HELD_COLOR_1
  # s5 = IS_PAUSED 
  # s6 = TICK_TIME
  # s7 = HELD_COLOR_2

##############################################################################
# Main
##############################################################################

	.text
	.globl main

    # Run the game.
main:
  #main function for running the game
  # temporaries - t0 is used briefly for loading tick_cycle
    # Initialize the game
    jal initialize_s_vals           # initialize s values 

    jal build_grid_template         # build grid template in memory 
    
    jal draw_background             # call the draw background function
    jal draw_border                 # call the draw border function

    jal initialize_fool             # initialize player pos and bounds, and draw first fool
    jal fill_first_three_rows_random


game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    xori $a3 $a3 1
    jal erase_fool
    jal draw_fool
    jal check_keyboard_input
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen

    lw $t0 TICK_CYCLE
    ble $s6 $t0 skip_down_shift
    li $s6 0
    jal check_game_over
    jal shift_down_by_one
    jal fill_first_row_random    #just to see update time 
  
    skip_down_shift:
    jal update_board                  # update the board 
    jal draw_arrows


	# 4. Sleep, and increment tick_time
      li $v0  32
      lw $a0 SLEEP_TIME
      add $s6 $s6 $a0
      syscall
    # 5. Go back to Step 1
    j game_loop

  game_over:
    # display some sort of game over message... YOU LOSE!
    
    li $v0, 10                      # end the program
    syscall


##############################################################################
# Display Functions
##############################################################################


initialize_fool:
  # function to initialize the fool, including setting PLAYER_POS and PLAYER_BOUND_LEFT, PLAYER_BOUND_RIGHT so s2 s3 s4
  # temporaries: t0 = bitmap address, t1 = grid height, t2 = grid horizontal offset, t3 = column width

    lw $t0 ADDR_DSPL                  # load grid specifications 
    lw $t1 GRID_HEIGHT
    lw $t2 GRID_HORIZONTAL_OFFSET
    lw $t3 COLUMN_WIDTH
        
    add $s2 $t0 $t1                   # set s2 to bottom
    add $s2 $s2 $t2
    add $s2 $s2 $t3
    move $t0 $s2                      # set t0 to bottom 
    sw $t0 PLAYER_1_BOUND_LEFT        # set player1 bound left 
    addi $t0 $t0 96                   # center t0 
    addi $s2 $t0 0                    # set player pos 
    addi $t0 $t0 96                   # center t0 
    sw $t0 PLAYER_1_BOUND_RIGHT       # set player2 bound right 

    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal draw_fool                     # draw fool 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 



draw_fool:
  # function to draw the fool
  # input: s2 should store a valid player position, a3 is 0 for left hand up, 1 for otherwise
  # This should be along the row of GRID_HEIGHT, or slightly below
  # temporaries: t0 = address to draw to, t1 = fool pattern address
  # t2 = red, t3 = green, t4 = gold, t5 = face, t6 = color to write
  # t7 = 512 if left hand is up (a1 is 0), -512 if right hand is up
  # t8 = horizontal stop condition
  # t9 = vertical stop condition

  move $t0 $s2          # store starting address in t0
  move $t1 $s2          # store starting address in t1
  lw $t2 CLOWN_COLOR_RED        # store red in t2
  lw $t3 CLOWN_COLOR_GREEN      # store green in t3
  lw $t4 CLOWN_COLOR_GOLD       # store gold in t4
  lw $t5 CLOWN_COLOR_FACE       # store face in t5
  lw $t6 CLOWN_COLOR_GREEN      # store a green (random, doens't matter) in t6
  addi $t8 $t0 32               # set horizontal loop condition
  addi $t9 $t0 4096             # set vertical loop condition

  # check which hand is up
  li $t7 0                         # load 0 to t7
  beq $t7 $a3 fool_left_hand_up    # check if a3 is equal to 0
  li $t7 512                       # load 4 to t7
  j draw_fool_loop                 # jump to fool loop
  
  fool_left_hand_up:
    li $t7 -512                    # load -4 to t7
    j draw_fool_loop               # jump to fool loop 

    
  draw_fool_loop:
    # decide which color, if any, to draw

    # check reds
    move $t1 $s2 
    addi $t1 $t1 20
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -8
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 1020
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red
    add $t1 $t1 $t7                  # add or subtract 512 depending on a1 
    beq $t1 $t0 set_fool_color_red 
    sub $t1 $t1 $t7 
    addi $t1 $t1 524                 # (512 + 12), shift right 3 down one 
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red

    # check greens 
    move $t1 $s2 
    addi $t1 $t1 8
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 8
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 1028                  # down two, right one, 512 + 512 + 4
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green 
    sub $t1 $t1 $t7                   # subtract +- 512
    beq $t1 $t0 set_fool_color_green
    add $t1 $t1 $t7
    addi $t1 $t1 500                          # down one, back three (512 - 12)
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green 

    # check face
    move $t1 $s2
    addi $t1 $t1 1548         # down three, over three (512 * 3 + 4 * 3)
    beq $t1 $t0 set_fool_color_face 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_face 

    # check bells 
    move $t1 $s2
    addi $t1 $t1 512
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 4
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 20
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 -512
    # beq $t1 $t0 set_fool_color_gold







    j skip_fool_write        # if no color is found, skip to next iteration 

    set_fool_color_red:
      move $t6 $t2           # store red into t6
      j draw_fool_write      # go to the write section of the loop
    set_fool_color_green:
      move $t6 $t3           # store green into t6
      j draw_fool_write      # go to the write section of the loop
    set_fool_color_gold:
      move $t6 $t4           # store gold into t6
      j draw_fool_write      # go to the write section of the loop
    set_fool_color_face:
      move $t6 $t5           # store face into t6
      j draw_fool_write      # go to the write section of the loop
     
  
    draw_fool_write:
      sw $t6 0($t0)                                # write the selected color to $t0
      skip_fool_write:
      addi $t0 $t0 4                               # increment t0
      beq $t8 $t0 draw_fool_horizontal_loop_end    # check for horizontal end condition
      j draw_fool_loop                             # return to start of loop 

    draw_fool_horizontal_loop_end:
      addi $t0 $t0 480           # rest address to beginning of next line (512 - 32)
      addi $t8 $t8 512           # reset horizontal end condition to end of next line
      beq $t0 $t9 draw_fool_loop_end           # check vertical end condition
      j draw_fool_loop

    draw_fool_loop_end:
      jr $ra                    # return

erase_fool:
  
  # function to erase the fool
  # input: s2 should store a valid player position
  # This should be along the row of GRID_HEIGHT, or slightly below
  # temporaries: t0 = address to draw to
  # t6 = background color
  # t8 = horizontal stop condition
  # t9 = vertical stop condition


  move $t0 $s2          # store starting address in t0
  lw $t6 BACKGROUND_COLOR      # store background color
  addi $t8 $t0 32               # set horizontal loop condition
  addi $t9 $t0 4096             # set vertical loop condition

  erase_fool_loop:
      sw $t6 0($t0)                                # write the selected color to $t0
      addi $t0 $t0 4                               # increment t0
      beq $t8 $t0 erase_fool_horizontal_loop_end    # check for horizontal end condition
      j erase_fool_loop                            # return to start of loop 

    erase_fool_horizontal_loop_end:
      addi $t0 $t0 480           # rest address to beginning of next line (512 - 32)
      addi $t8 $t8 512           # reset horizontal end condition to end of next line
      beq $t0 $t9 erase_fool_loop_end           # check vertical end condition
      j erase_fool_loop

    erase_fool_loop_end:
      jr $ra                    # return



draw_background:
    #function to draw the background
    lw $t1, BACKGROUND_COLOR        # t1 = background color (dark purple)
    lw $t0, ADDR_DSPL       # t0 = base address for display 
    li $t2, 65536           # set ending condition for loop
    add $t2, $t2, $t0       
    background_loop:
      sw $t1, 0($t0)
      addi $t0, $t0, 4
      ble $t2, $t0, background_loop_end
      j background_loop
    background_loop_end:
      jr $ra


        
draw_border:
  # function to draw the border of the magical drop playing field
  # temporaries: 
  # t0: first column address, t1: second column address, t3: horizontal end condition, t4: vertical end condition 
  # t5: color, t6: horizontal grid offset, t7: grid width, t8: column width

  #load the temporaries
  lw $t0, ADDR_DSPL
  lw $t4, GRID_HEIGHT
  lw $t5, BORDER_COLOR
  lw $t6, GRID_HORIZONTAL_OFFSET
  lw $t7, GRID_WIDTH
  lw $t8, COLUMN_WIDTH
  add $t0, $t0, $t6        #set the first column address
  add $t1, $t8, $t7        #set the second column address
  add $t1, $t1, $t0        # ^
  add $t3, $t8, $t0        # set horizontal end condition based on col width
  add $t4, $t4, $t0        # set vertical end condition based on grid height
  

  border_loop_column:
      sw $t5, 0($t0)
      sw $t5, 0($t1)
      addi $t0, $t0, 4
      addi $t1, $t1, 4
      ble $t3, $t0, border_loop_horizontal_end
      j border_loop_column

    border_loop_horizontal_end:      
      addi $t0, $t0, 512         #reset column addresses to start of next line
      sub $t0, $t0, $t8
      addi $t1, $t1, 512         #reset column addresses to start of next line
      sub $t1, $t1, $t8
      addi $t3, $t3, 512         # increment the horizontal end condition
      ble $t4, $t0, border_loop_vertical_end
      j border_loop_column

  border_loop_vertical_end:
      jr $ra





draw_bubble:
  # draws a bubble with a top left corner specified by $a0, color specified by $a1
  # temporaries: t0 = address, t4 = written color, 
  # t7 = bubble pattern t8 = horizontal stop condition, t9 = vertical stop condition
  
  move $t0 $a0               # store the top left corner of bubble to be drawn in t0
  addi $t8 $t0 32            # set t8 to horizontal loop condition
  addi $t9 $t0 4096          # set t9 to vertical loop condition 

  draw_bubble_loop:
    # if assigned color is background color, skip color selection
    lw $t4 BACKGROUND_COLOR    # set t4 to background color
    beq $a1 $t4 draw_bubble_write
    
    #choose which color for t4 based on position of t0

    #check corners
    move $t7 $a0
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 4
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 20
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 4
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 512
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 -28
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 2560
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 28
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 512
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 -4
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 -20
    beq $t0 $t7 set_bubble_color_background
    addi $t7 $t7 -4
    beq $t0 $t7 set_bubble_color_background

    #check sheen
    move $t7 $a0
    addi $t7 $t7 528
    beq $t0 $t7 set_bubble_color_sheen
    addi $t7 $t7 512
    beq $t0 $t7 set_bubble_color_sheen
    addi $t7 $t7 4
    beq $t0 $t7 set_bubble_color_sheen
    addi $t7 $t7 512
    beq $t0 $t7 set_bubble_color_sheen
    addi $t7 $t7 4
    beq $t0 $t7 set_bubble_color_sheen

    #else, set to default color
    j set_bubble_color_col


    set_bubble_color_col:
      move $t4 $a1
      j draw_bubble_write
    set_bubble_color_background:
      lw $t4 BACKGROUND_COLOR
      j draw_bubble_write
    set_bubble_color_sheen:
      lw $t4 COLOR_SHEEN
      j draw_bubble_write

    draw_bubble_write:
    # write the color
    sw $t4 0($t0)
    addi $t0 $t0 4
    beq $t8 $t0 draw_bubble_horizontal_end
    j draw_bubble_loop

    draw_bubble_horizontal_end:
        addi $t0 $t0 480       # reset the address to beginning of next line (512 - 32)
        addi $t8 $t8 512       # set horizontal end condition to end of next line
        beq $t0 $t9 draw_bubble_loop_end
        j draw_bubble_loop

    draw_bubble_loop_end:
      jr $ra



update_board:
  # function to update the bitmap based on CURRENT_GRID
  # calls helper function draw bubble which uses t1, 4, 7-9
  # temporaries: t5 = grid template index, t6 = grid template loop end value
  # t2 = current grid color, t3 = current grid address
  
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 GRID_TEMPLATE       # load GRID_TEMPLATE to t5
    la $t3 CURRENT_GRID        # load CURRENT_GRID to t3 
    addi $t6 $t5 392           # set t6 to loop end condition


  
    update_board_loop:
        lw $a1 0($t3)          # store color of CURRENT_GRID in a1 (parameter for draw_bubble)
        lw $a0 0($t5)          # store values of GRID_TEMPLATE in a0 (parameter for draw_bubble)
        jal draw_bubble        # call draw_bubble
        addi $t5 $t5 4         # increment t5 by 4
        addi $t3 $t3 4         # increment t3 by 4
        beq $t5 $t6 update_board_loop_end          # check if loop is over
        j update_board_loop    # restart loop

    update_board_loop_end:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return 
  
        
fill_first_three_rows_random:
    # fills the first three rows with randomly colored bubbles
    # helper functions: calls get_random_color, which uses t0-3
    # only changes the values stored in current grid, nothing else
    # temporaries: t5 = Current grid index, t6 = loop end condition

    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 CURRENT_GRID        # set t5 to current grid 
    addi $t6 $t5 84            # set t6 to loop end condition

  
    random_fill_first_three_rows_loop:
        jal get_random_color   # call get_random_color
        sw $v0 0($t5)          # store the randomly generated color into CURRENT_GRID
        addi $t5 $t5 4         # increment t5 by 4
        beq $t5 $t6 random_fill_first_three_rows_loop_end          # check if loop is over
        j random_fill_first_three_rows_loop                        # restart loop

    random_fill_first_three_rows_loop_end:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return

fill_first_row_random:
    # fills the first singular row with randomly colored bubbles
    # helper functions: calls get_random_color, which uses t0-3
    # only changes the values stored in current grid, nothing else
    # temporaries: t5 = Current grid index, t6 = loop end condition

    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 CURRENT_GRID        # set t5 to current grid 
    addi $t6 $t5 28            # set t6 to loop end condition

  
    random_fill_first_row_loop:
        jal get_random_color   # call get_random_color
        sw $v0 0($t5)          # store the randomly generated color into CURRENT_GRID
        addi $t5 $t5 4         # increment t5 by 4
        beq $t5 $t6 random_fill_first_row_loop_end          # check if loop is over
        j random_fill_first_row_loop                        # restart loop

    random_fill_first_row_loop_end:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return


shift_down_by_one:
  # function to move everything in the current grid down by one row 
  # temporaries: t3 = address of bottom right corner of CURRENT_GRID, decremented by 4
  # t4 = address 2 rows above t3, t5 = color two rows above t3, t6 = loop end condition

    la $t3 CURRENT_GRID        # set t3 to current grid  
    addi $t6 $t3 28            # set t6 to loop end condition
    addi $t3 $t3 388           # set $t3 to bottom right
    
    shift_down_by_one_loop:
        addi $t4 $t3 -28       # set t4 to the address of the bubble one row above
        lw $t5 0($t4)          # set t5 to color of t4's bubble
        sw $t5 0($t3)          # set t3's bubble to t5 color (color of the bubble one row below)
        addi $t3 $t3 -4         # increment t3 by -4
        blt $t3 $t6 shift_down_by_one_loop_end          # check if loop is over
        j shift_down_by_one_loop    # restart loop

    shift_down_by_one_loop_end:
        jr $ra                   # return 


  

draw_arrows:
    # draws arrow based on player pos s2 going up until it hits a bubble in Current_grid
    # will draw arrows facing up or down depending on s1 (bubbles held)
    # uses helper functions get_fool_grid_pos and get_lowest_bubble_grid_pos, which use t0-3
    # temporaries: t9 = first block to draw arrows in, t8 = last block to draw arrows in
    
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_fool_grid_pos      # gets fool grid position into v0 
    addi $t9 $v0 0             # set t9 to start grid pos 
    jal get_lowest_bubble_grid_pos    # sets v0 to position of the lowest bubble, v1 to 1 if none is found and 0 if it exists
    addi $t8 $v0 0             # set t8 to end grid pos 
    sub $t8 $t8 $v1            # if a bubble is found, this does nothing. If no bubble is found, then we decrement the ending index by one 

    draw_arrows_loop:
      ble $t9 $t8 end_draw_arrows        # if the index we want to draw arrows to is above or at the ending index, we end the loop
      addi $a0 $t9 0                     # set a0 to the grid pos we want to draw to 
      jal draw_arrow_block               # draws a block of arrows 
      addi $t9 $t9 -28                   # decrement grid pos down a row
      j draw_arrows_loop
    
    end_draw_arrows:
    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 


draw_arrow_block:
    # function to fill a given block with arrows 
    # takes parameters a0 = block of current grid to draw to
    
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_pixel_from_grid    # stores the top left pixel value of a0 into v0 (assume a0 is already declared as input)
    addi $a0 $v0 12            # centers a0 to top center of the given block 
    addi $a0 $a0 512          # moves the index down two rows 
    jal draw_arrow             # draws an arrow at the given position
    addi $a0 $a0 2048          # moves the index down three rows 
    jal draw_arrow             # draws an arrow at the given position

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 

draw_arrow:
  # helper function to draw a single arrow centered at a given address of the bitmap (left centered, i.e. in 0-31, would be 15)
  # takes inputs: a0 = address of the centermost top pixel
  # temporaries: t0 = address to write to, t1 = color, t2 up/down (-512 for pointing down, 0 for pointing up)
  # saves: s1, checks if holding
  # PRECONDITION cannot be outside valid range or gonna get errors (valid range for bitmap)

  addi $t0 $a0 0              # set to to starting address 
  lw $t1 COLOR_ARROW         # set t1 to arrow color 


  # check if going up or down
  bne $s1 0 draw_arrow_pointing_up
  li $t2 -512
  j start_drawing_arrow

  draw_arrow_pointing_up:
  li $t2 0
  j start_drawing_arrow

  start_drawing_arrow:
  sw $t1 0($t0)               # store color in bitmap
  addi $t0 $t0 4              # shift address
  sw $t1 0($t0)               # store color in bitmap
  addi $t0 $t0 512              # shift address
  sw $t1 0($t0)               # store color in bitmap
  addi $t0 $t0 -4              # shift address
  sw $t1 0($t0)               # store color in bitmap

  addi $t0 $t0 -4              # shift address
  add $t0 $t0 $t2             # move index up or stay in place
  sw $t1 0($t0)               # store color in bitmap
  addi $t0 $t0 12             # shift address
  sw $t1 0($t0)               # store color in bitmap


    

  jr $ra                      # return




##############################################################################
# Helper Functions
##############################################################################


initialize_s_vals:
  # function to initialize s values
  # Only initializes the simple ones, others have their own methods
  # SAVED REGISTERS 
  # s0 = CHACACTER_POS_2 (external)
  # s1 = BUBBLES_HELD_1 
  # s2 = CHARACTER_POS_1 (external)
  # s3 = BUBBLES_HELD_2
  # s4 = HELD_COLOR_1 
  # s5 = IS_PAUSED 
  # s6 = TICK_TIME
  # s7 = HELD_COLOR_2
  li $s1 0        # set s6 to 0 
  li $s3 0        # set s6 to 0 
  lw $s4 BACKGROUND_COLOR        # set s4 to BACKGROUND_COLOR
  li $s5 0        # set s5 to 0
  li $s6 0        # set s6 to 0 
  lw $s7 BACKGROUND_COLOR        # set s7 to BACKGROUND_COLOR
  jr $ra          # return
  


get_random_color:
    #returns a random color, red green blue or yellow, in $v0
    # temporaries: a0 = rng, t0 = 0, t1 = 1, t2 = 2, t3 = 3
    
    li $v0 42            # make random number 0-3
    li $a0 0
    li $a1 4
    syscall
    li $t0 0
    li $t1 1
    li $t2 2
    li $t3 3
    beq $a0 $t0 random_return_red
    beq $a0 $t1 random_return_blue
    beq $a0 $t2 random_return_green
    beq $a0 $t3 random_return_yellow

    random_return_red:
      lw $v0 COLOR_RED
      jr $ra
    random_return_blue:
      lw $v0 COLOR_BLUE
      jr $ra
    random_return_green:
      lw $v0 COLOR_GREEN
      jr $ra
    random_return_yellow:
      lw $v0 COLOR_YELLOW
      jr $ra
    

  build_grid_template:
    # function to build the grid template (see .data for details) and current grid
    # temporaries: $t0 = address to be stored, $t1 = horizontal loop condition, $t2 = vertical loop condition, t3 = GRID_TEMPLATE, t4 = CURRENT_GRID
    # t5 = background color
    # $t8 = grid horizontal offset, t9 = column width

    lw $t0 ADDR_DSPL                  # store ADDR_DSPL in t0
    lw $t8 GRID_HORIZONTAL_OFFSET     # store GRID_HORIZONTAL_OFFSET in t8
    lw $t9 COLUMN_WIDTH               # store COLUMN_WIDTH in t9
    add $t0 $t0 $t8                   # add offset and column width to initial address to obtain start of grid template
    add $t0 $t0 $t9                   
    addi $t1 $t0 224                  # set t1 to initial horizontal loop condition
    addi $t2 $t0 53744                # set t2 to vertical loop condition
    la $t3 GRID_TEMPLATE              # set t3 to GRID_TEMPLATE address
    la $t4 CURRENT_GRID               # set t4 to CURRENT_GRID
    lw $t5 BACKGROUND_COLOR           # set t5 to background color 

    grid_builder_loop:
      sw $t0 0($t3)                   # store t0 in GRID_TEMPLATE through t3
      sw $t5 0($t4)                   # store background_color in CURRENT GRID
      addi $t0 $t0 32                 # increment t0 by 32
      addi $t3 $t3 4                  # increment t3 by 4
      addi $t4 $t4 4                  # increment t4 by 4 
      beq $t0 $t1 horizontal_grid_builder_loop_end        # check horizontal loop condition
      j grid_builder_loop                                 # jump to start of loop 
      
      horizontal_grid_builder_loop_end:
        addi $t0 $t0 -224              # increment t0 back to start of row
        addi $t0 $t0 4096              # increment t0 down 8 rows
        addi $t1 $t1 4096              # increment t1, horizontal loop condition
        bgt $t0 $t2 grid_builder_loop_end                   # check vertical loop condition
        j grid_builder_loop           # jump to start of loop
      grid_builder_loop_end:
        jr $ra                        # return 


get_fool_grid_pos:
  # helper function to return the bottommost index of the column that the fool is standing in from CURRENT_GRID
  # returns that value (364, 368, 372, 376, 380, 384, 388) in v0
  # temporaries: t0 = potential positions, t1 current grid 

  la $t1 CURRENT_GRID

  #could be implemented with a loop, writing it out is faster though, involves shifting and math (could optimize this later though)
  lw $t0 PLAYER_1_BOUND_LEFT         # set left position 
  beq $s2 $t0 get_pos_0              # check through all possible positions ... 
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_1
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_2
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_3
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_4
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_5
  addi $t0 $t0 32
  beq $s2 $t0 get_pos_6
  addi $t0 $t0 32

  get_pos_0:
    addi $v0 $t1 364       # set value to appropriate position
    jr $ra                 # return
  get_pos_1:
    addi $v0 $t1 368       # set value to appropriate position
    jr $ra                 # return
  get_pos_2:
    addi $v0 $t1 372       # set value to appropriate position
    jr $ra                 # return
  get_pos_3:
    addi $v0 $t1 376       # set value to appropriate position
    jr $ra                 # return
  get_pos_4:
    addi $v0 $t1 380       # set value to appropriate position
    jr $ra                 # return
  get_pos_5:
    addi $v0 $t1 384       # set value to appropriate position
    jr $ra                 # return
  get_pos_6:
    addi $v0 $t1 388       # set value to appropriate position
    jr $ra                 # return



get_lowest_bubble_grid_pos:
  # function to fetch the grid position of the lowest bubble above the fool 
  # returns that value in v0, returns 0 in v1 if there is a bubble and 1 if none is found, returns pixel value in v2
  # temporaries: t0 = grid color checked t1 = background color t2 = grid color stored, t3 = min val 

  # push ra to stack
  addi $sp, $sp, -4          # moves stack pointer a word
  sw $ra 0($sp)              # push a word onto the stack

  jal get_fool_grid_pos      # fetch the grid position of the fool into v0
  lw $t1 BACKGROUND_COLOR    # store background color into t1 
  la $t3 CURRENT_GRID        # load current grid to t3 
  lw $t3 0($t3)              # store minimum value of current_grid in t3
  addi $t0 $v0 0             # set t0 to grid position above the fool 

  check_lowest_bubble_loop:
    lw $t2 0($t0)            # load the color stored in current_grid into t2
    bne $t1 $t2 return_lowest_bubble         # if the value is not the background color, return the position 
    addi $t0 $t0 -28         # shift the place we're checking down by 28 
    blt $t0 $t3 return_empty_lowest_bubble   # check if it's out of bounds 
    j check_lowest_bubble_loop

  return_lowest_bubble:
    li $v1 0                # set v1 to 0, indicating we found a bubble (or we did not find nothing)
    addi $v0 $t0 0          # set v0 to value that has a bubble 
    j end_lowest_bubble 
  
  return_empty_lowest_bubble:
    addi $t0 $t0 28         # shift the index back to the top row
    li $v1 1                # set v1 to 1, meaning no bubble is found (or emptiness was found)
    addi $v0 $t0 0          # set v0 to top row above the fool 
    j end_lowest_bubble
    

  end_lowest_bubble:
    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 


get_pixel_from_grid:
  # function to get the pixel position of the top left corner of a given CURRENT_GRID slot (using grid template)
  # takes parameter a0 = current_grid index
  # returns v0 = pixel pos
  # temporaries: t0 = a0 grid index, t1 = start of current grid, t2 = return value address

  la $t0 GRID_TEMPLATE       # load t0 with grid template 
  la $t1 CURRENT_GRID        # load t1 with current grid 
  sub $t2 $a0 $t1            # set t2 to the difference between the parameter and the current grid start 
  add $t2 $t2 $t0            # add that difference (t2) to the start of grid template
  lw $v0 0($t2)              # load the pixel pos stored in grid template at the address t2 

  # move $a0 $v0
  # lw $a1 COLOR_SHEEN
  # jal draw_bubble
  
  jr $ra                     # return 
  

check_game_over:
  # function to check of the game ends
  # temporaries: t3 = bottom right, t4 = background color, t5 = addressed color, t6 = loop end condition
  
    la $t3 CURRENT_GRID        # load current grid to t3 
    addi $t6 $t3 364           # set t6 to loop end condition
    addi $t3 $t3 388           # set $t3 to bottom right
    lw $t4 BACKGROUND_COLOR    # set t4 to background color
    
    check_game_over_loop:
        lw $t5 0($t3)          # set t5 to color of t4's bubble
        bne $t5 $t4 check_game_over_is_over       # if the color is not background, game is over
        addi $t3 $t3 -4        # increment t3 by -4
        blt $t3 $t6 check_game_over_loop_end          # check if loop is over
        j check_game_over_loop    # restart loop

    check_game_over_loop_end:
        jr $ra                   # return 

    check_game_over_is_over:
      jal shift_down_by_one
      j game_over
      


##############################################################################
# Input Functions
##############################################################################

check_keyboard_input:
  # function for checking if a key has been pressed and which one
  # temporaries: t0 = keyboard address, t1 = first word, t2 = second word
  
	li 		$v0, 32                 # perfrom syscall 
	li 		$a0, 1
	syscall

    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t1, 0($t0)                  # Load first word from keyboard
    beq $t1 1, keyboard_input      # If first word 1, key is pressed

    end_check_keyboard_input:
    jr $ra 

    keyboard_input:
      # perform input check
      lw $t2, 4($t0)                  # Load second word from keyboard
      lw $t1, 0($t0)                  # Check if stack is empty
      beq $t1 1 keyboard_input        # loop until stack is empty

      beq $t2, 0x70, p_pressed        # Check if the key q was pressed
      beq $t2, 0x71, q_pressed        # Check if the key q was pressed
      beq $t2, 0x61, a_pressed        # check if key a was pressed 
      beq $t2, 0x64, d_pressed        # check if key d was pressed 
      beq $t2, 0x77, w_pressed        # check if key w was pressed 
      beq $t2, 0x73, s_pressed        # check if key s was pressed 
      # ... check other keys 

      j end_check_keyboard_input      # end

    p_pressed:
      #TODO implement this function (or helper functions, need to display a paused message somehow)
      # sub function handling the case when keyboard input is p
      # pauses the game
      # toggles s5 between 0 and 1
      # temporaries: t0 = 0

      
      
      li $t0 0                       # load 0 to t0
      beq $t0 $s5 p_pressed_pause    # check if t0 is equal to s5 (if s5 = 0, if game is not paused)
      li $s5 0
      j end_check_keyboard_input
      
      p_pressed_pause:
      li $s5 1
      j end_check_keyboard_input

    q_pressed:
      li $v0, 10                      # Quit gracefully
      syscall


    a_pressed:
      # function to handle when a key is pressed
      # moves player_pos left by 32, if does not exceed the bound
      # temporaries: t0 = s2 - 32, = player pos - 32, t1 = left bound

      lw $t1 PLAYER_1_BOUND_LEFT    # set t1 to left bound 
      addi $t0 $s2 -32              # set t0 to playerpos - 32
      bge $t0 $t1 move_fool_left    # check if moving left takes the fool beyond the border
      j end_check_keyboard_input    # end keyboard input
      move_fool_left:
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal erase_fool
      addi $s2 $s2 -32              # move player pos one unit left
      jal draw_fool
      
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      j end_check_keyboard_input    # end keyboard input 

    d_pressed:
      # function to handle when d key is pressed
      # moves player_pos right by 32, if does not exceed the bound
      # temporaries: t0 = s2 + 32, = player pos + 32, t1 = right bound 

      lw $t1 PLAYER_1_BOUND_RIGHT   # set right bound to t1 
      addi $t0 $s2 32               # set t0 to playerpos + 32
      ble $t0 $t1 move_fool_right   # check if moving left takes the fool beyond the border
      j end_check_keyboard_input    # end keyboard input
      move_fool_right:
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal erase_fool
      addi $s2 $s2 32              # move player pos one unit left
      jal draw_fool
      
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      j end_check_keyboard_input    # end keyboard input 

  w_pressed:
    # TODO: implement throw control
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      li $s1 0                   # sets BUBBLES_HELD to 0

      jal get_lowest_bubble_grid_pos     # returns grid pos in v0, returns 0 in v1 if there is a bubble 


      no_bubble_found:
      
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

    j end_check_keyboard_input    # end keyboard input 


  s_pressed:
    # TODO: implement grab control 

      # v0 is current grid position(column * 7)
      # v1 is 0 if there is a bubble in the column
      # $t4 is background color
      # $t5 is grid_base
      # $t6 is lowest bubble color

      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal get_lowest_bubble_grid_pos
      
      bne $s1 $zero check_colors_match # if already holding a bubble, check if colors match

      # if no bubbles are held
      addi $s4 $t6 0            # set grabbing color to color of lowest bubble
      j grab_setup # if not holding a bubble, grab bubbles

    check_colors_match:
      bne $t6 $s4 grab_done    #  if, different color, exit

    grab_setup:
      lw $t4 BACKGROUND_COLOR          # t4 = background color
      la $t5 CURRENT_GRID              # t5 = grid base (upper bound)

    # goes up to see if others in column touching are same color
    grab_loop:
      lw  $t6 0($v0)                   # get xcolor of the current slotdsd
      bne $t6 $s4 grab_done            # if color does not match current color, exit
      sw  $t4 0($v0)                   # clear the slot
      addi $s1 $s1 1                   # register one more bubble held
      addi $v0 $v0 -28                 # go one row up
      blt $v0 $t5 grab_done            # if past the top of the grid, exit
      j grab_loop

      # loads ra to be ra of caller of loop and not get_lowest_bubble, i.e. exit
      grab_done:
        # pull ra from stack 
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
  
        j end_check_keyboard_input    # end keyboard input
      
      

##############################################################################
# ...
##############################################################################

  