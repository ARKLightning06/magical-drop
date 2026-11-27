################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Andrew Koes, 1012691482
# Student 2: Andrew Li, 1012142441
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
    .word 120
# Tick time
TICK_CYCLE:
    .word 5000
# combo time 
COMBO_TIME:
  .word 5

# Grid template - Stores 7 x 14 words, each representing the top left corner of one of the bubbles in the grid 
.align 2
GRID_TEMPLATE:
    .space 392
CURRENT_GRID:
    .space 392
GRID_TEMPLATE_2:
    .space 392
CURRENT_GRID_2:
    .space 392

# Grid specifications
GRID_HORIZONTAL_OFFSET:
    .word 0
GRID_HORIZONTAL_OFFSET_2:
    .word 256
GRID_WIDTH:
    .word 224
COLUMN_WIDTH:
    .word 16
GRID_HEIGHT:
    .word 57344

# Player specifications (set in initialize_fool)
PLAYER_1_BOUND_LEFT:
  .word 0
PLAYER_1_BOUND_RIGHT:
  .word 0
PLAYER_2_BOUND_LEFT:
  .word 0
PLAYER_2_BOUND_RIGHT:
  .word 0

# Bubbles to pop: this is an array storing a timer followed by a series of bubbles to pop (grid positions in current grid) 
PLAYER_1_BUBBLESQUEUE:
  .space 392
PLAYER_2_BUBBLESQUEUE:
  .space 392

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
    jal reset_bubblequeue           # clear bubble array to 0s
    jal build_grid_template         # build grid template in memory 
    jal build_grid_template_2       # build grid template 2 in memory 
    
    jal draw_background             # call the draw background function
    jal draw_border                 # call the draw border function
    jal draw_border_2               # call the second draw border function 

    jal initialize_fool             # initialize player pos and bounds, and draw first fool
    jal initialize_fool_2           # "" for 2 
    jal fill_first_three_rows_random
    jal fill_first_three_rows_random_2


game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    xori $a3 $a3 1
    jal erase_fool
    jal erase_fool_2
    jal draw_fool
    jal draw_fool_2
    jal check_keyboard_input
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen

    lw $t0 TICK_CYCLE
    ble $s6 $t0 skip_down_shift

    # shift down 
    li $s6 0
    jal check_game_over              # TODO: combine these to check for winner, loser, or tie conditions
    jal check_game_over_2 
    jal shift_down_by_one
    jal shift_down_by_one_2
    jal shift_bubblesqueue_by_one     # shift bubblesque
    jal shift_bubblesqueue_by_one_2     # shift bubblesque2
    jal fill_first_row_random         # just to see update time 
    jal fill_first_row_random_2
  
    skip_down_shift:
    jal decrement_all_bubblesets      # decrement all bubblesets 
    jal decrement_all_bubblesets_2      # decrement all bubblesets 
    jal update_board                  # update the board 
    jal update_board_2
    jal draw_arrows
    jal draw_arrows_2


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
  # function to initialize the fool, including setting PLAYER_POS and PLAYER_BOUND_LEFT, PLAYER_BOUND_RIGHT so s2 
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
  li $s1 0        # set s1 to 0 
  li $s3 0        # set s3 to 0 
  lw $s4 BACKGROUND_COLOR        # set s4 to BACKGROUND_COLOR
  li $s5 0        # set s5 to 0
  li $s6 0        # set s6 to 0 
  lw $s7 BACKGROUND_COLOR        # set s7 to BACKGROUND_COLOR

# for testing purposes (TODO: DELETE)
  lw $s4 COLOR_RED
  # li $s1 8
  
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
  
  jr $ra                     # return


is_in_left_column:
  # helper function checking if a given grid position is in the left column of the bitmap
  # could be implemented more elegantly with math, but seems more efficient to brute force it 
  # takes input parameter a0 = index being checked
  # outputs v0, which is 0 if not in left column, 1 if yes in left column
  # temporaries: t3 = address checking, t4 = ending loop condition

  li $v0 0           # set v0 to 0 
  la $t3 CURRENT_GRID
  addi $t4 $t3 392  # set to loop end condition 
  is_in_left_column_loop:
    bge $t3 $t4 in_left_column_return_false      # if index goes out of bounds, end loop 
    beq $a0 $t3 in_left_column_return_true       # if parameter is equal to index being checked, return true 
    addi $t3 $t3 28                              # increment t3 down a column 
    j is_in_left_column_loop
    

  in_left_column_return_true:
    li $v0 1     # set v0 to 1 
  in_left_column_return_false:
    jr $ra       # return 


is_in_right_column:
  # helper function checking if a given grid position is in the right column of the bitmap
  # could be implemented more elegantly with math, but seems more efficient to brute force it 
  # takes input parameter a0 = index being checked
  # outputs v0, which is 0 if not in left column, 1 if yes in left column
  # temporaries: t3 = address checking, t4 = ending loop condition

  li $v0 0           # set v0 to 0 
  la $t3 CURRENT_GRID
  addi $t4 $t3 392  # set to loop end condition 
  addi $t3 $t3 24   # set t3 to top of right column 
  is_in_right_column_loop:
    bge $t3 $t4 in_right_column_return_false      # if index goes out of bounds, end loop 
    beq $a0 $t3 in_right_column_return_true       # if parameter is equal to index being checked, return true 
    addi $t3 $t3 28                              # increment t3 down a column 
    j is_in_right_column_loop
    

  in_right_column_return_true:
    li $v0 1     # set v0 to 1 
  in_right_column_return_false:
    jr $ra       # return 


add_neighbors_to_bubbleset_recursive:
  # function to add neighbors of a given bubble to the last bubbleset, which recurses until no neighbors of the same color are adjacent 
  # takes input a0 = bubble to check neighbors (which should already be in the bubbleset)
  # uses helper function is_in_bubblesqueue, which takes a0 input as a grid position and returns v0 as 0 if false, 1 if true (0 if not in, 1 if in), also uses temps 0-2
  # uses helper function add_to_bubbleset, which uses t0-2 and takes input parameter a0 = grid pos being added 
  # uses helper functions is_in_left_column and is_in_right_column, which takes input parameter a0 = grid position being checked, returns v0 = 0 if not in col, 1 if in  
  # temporaries t9 = neighbor address, t8 = bound to check, t7 = main color, t6 = neighbor color 
  
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t8 CURRENT_GRID        # set t8 to current grid 
    addi $t9 $a0 0             # set t9 to address to check 
    lw $t7 0($t9)              # load the color of a0 into t7 

    recurse_below:    # in hindsight, this naming convention is slightly misleading... below in memory, though it's checking the position above in the bitmap
    addi $t9 $t9 -28           # check below 
    la $t8 CURRENT_GRID        # set t8 to current grid 
    blt $t9 $t8 recurse_above  # if out of bounds, end
    lw $t6 0($t9)              # load the neighbor bottom color to t6 
    bne $t6 $t7 recurse_above  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_above    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_above

    recurse_above:         # position above in memory, below in bitmap
    addi $t9 $t9 56        # move t9 up two rows, to check the upper neighbor 
    la $t8 CURRENT_GRID        # set t8 to current grid 
    addi $t8 $t8 388       # set t8 to lower bound (spatially, upper bound numerically)
    bgt $t9 $t8 recurse_left  # if out of bounds, end
    lw $t6 0($t9)              # load the neighbor upper color to t6 
    bne $t6 $t7 recurse_left  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_left    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_left

    recurse_left:
    addi $t9 $t9 -32        # move t9 up one row then to the left, to check the left neighbor...  
    la $t8 CURRENT_GRID        # set t8 to current grid 
    blt $t9 $t8 recurse_right  # if out of bounds, end
    addi $a0 $t9 0          # set a0 to t9 
    jal is_in_right_column  # set v0 to 0 if not in right col, 1 if is in right col 
    bne $v0 $zero recurse_right     # if t9 is in right column, then t9 + 4 is in left column, so end recursion (so check if v0 doesn't equal 0)
    lw $t6 0($t9)              # load the neighbor upper color to t6 
    bne $t6 $t7 recurse_right  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_right    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_right

  recurse_right:
    addi $t9 $t9 8        # move t9 right two, shifting from left neighbor to right neighbor   
    la $t8 CURRENT_GRID     # set t8 to lower bound
    addi $t8 $t8 392        # set t8 to upper bound 
    bge $t9 $t8 finish_recursing  # if out of bounds, end
    addi $a0 $t9 0          # set a0 to t9 
    jal is_in_left_column  # set v0 to 0 if not in left col, 1 if is in left col 
    bne $v0 $zero finish_recursing     # if t9 is in right column, then t9 + 4 is in left column, so end recursion (so check if v0 doesn't equal 0)
    lw $t6 0($t9)              # load the neighbor right color to t6 
    bne $t6 $t7 finish_recursing  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue     # check if a0 is in bubblesqueue 
    beq $v0 1 finish_recursing    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j finish_recursing

    finish_recursing:

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 


check_game_over:
  # function to check of the game ends
  # temporaries: t3 = bottom right, t4 = background color, t5 = addressed color, t6 = loop end condition
  
    la $t3 CURRENT_GRID        # load current grid to t3 
    addi $t6 $t3 364           # set t6 to loop end condition
    addi $t3 $t3 388           # set $t3 to bottom right
    lw $t4 BACKGROUND_COLOR    # set t4 to background color
    
    check_game_over_loop:
        lw $t5 0($t3)          # set t5 to color of t3's bubble
        bne $t5 $t4 check_game_over_is_over       # if the color is not background, game is over
        return_to_check_game_over_loop:           # for when we check bubblequeue membership 
        addi $t3 $t3 -4        # increment t3 by -4
        blt $t3 $t6 check_game_over_loop_end          # check if loop is over
        j check_game_over_loop    # restart loop

    check_game_over_loop_end:
        jr $ra                   # return 

    check_game_over_is_over:
      # first check if index is in bubblesqueue 
      addi $a0 $t3 0            # set a0 to t3 
      
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal is_in_bubblesqueue     # stores into v0 0 if a0 is not in bubblequeue, 1 if it is

      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      beq $v0 $zero check_game_over_is_over_for_real
      j return_to_check_game_over_loop

      check_game_over_is_over_for_real:
      jal shift_down_by_one
      j game_over
      


##############################################################################
# Input Functions
##############################################################################

check_keyboard_input:
  # function for checking if a key has been pressed and which one
  # temporaries: t0 = keyboard address, t1 = first word, t2 = second word, t3 = player1 action, t4 = player2 action, t5 = general action 
  
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
      lw $t3, 4($t0)                  # Load second word from keyboard
      lw $t1, 0($t0)                  # Check if stack is empty

      # store latest p1 input into t2 
      beq $t3, 0x61, store_p1_input        # check if key a was pressed 
      beq $t3, 0x64, store_p1_input        # check if key d was pressed 
      beq $t3, 0x77, store_p1_input        # check if key w was pressed 
      beq $t3, 0x73, store_p1_input        # check if key s was pressed 

      # store latest p2 input into t4
      beq $t3, 0x69, store_p2_input        # check if key i was pressed 
      beq $t3, 0x6A, store_p2_input        # check if key j was pressed 
      beq $t3, 0x6B, store_p2_input        # check if key k was pressed 
      beq $t3, 0x6C, store_p2_input        # check if key l was pressed 

      # store latest general input into t5 
      beq $t3, 0x70, store_general_input        # Check if the key q was pressed
      beq $t3, 0x71, store_general_input        # Check if the key q was pressed


      store_p1_input:
        addi $t2 $t3 0                # set t2 to t3
        j continue_keyboard_input

      store_p2_input:
        addi $t4 $t3 0                # set t2 to t3
        j continue_keyboard_input

      store_general_input:
        addi $t5 $t3 0                # set t5 to t3
        j continue_keyboard_input

      continue_keyboard_input:
      beq $t1 1 keyboard_input        # loop until stack is empty

      process_general_inputs:
      beq $t5, 0x70, p_pressed        # Check if the key q was pressed
      beq $t5, 0x71, q_pressed        # Check if the key q was pressed

      process_p1_inputs:
      beq $t2, 0x61, a_pressed        # check if key a was pressed 
      beq $t2, 0x64, d_pressed        # check if key d was pressed 
      beq $t2, 0x77, w_pressed        # check if key w was pressed 
      beq $t2, 0x73, s_pressed        # check if key s was pressed 

      process_p2_inputs:
      beq $t4, 0x69, i_pressed         # check if key i was pressed 
      beq $t4, 0x6A, j_pressed        # check if key j was pressed 
      beq $t4, 0x6B, k_pressed        # check if key k was pressed 
      beq $t4, 0x6C, l_pressed        # check if key l was pressed 

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
      j process_p1_inputs
      
      p_pressed_pause:
      li $s5 1
      j process_p1_inputs

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
      j process_p2_inputs    # end keyboard input
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

      j process_p2_inputs    # end keyboard input

    d_pressed:
      # function to handle when d key is pressed
      # moves player_pos right by 32, if does not exceed the bound
      # temporaries: t0 = s2 + 32, = player pos + 32, t1 = right bound 

      lw $t1 PLAYER_1_BOUND_RIGHT   # set right bound to t1 
      addi $t0 $s2 32               # set t0 to playerpos + 32
      ble $t0 $t1 move_fool_right   # check if moving left takes the fool beyond the border
      j process_p2_inputs    # end keyboard input
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

      j process_p2_inputs    # end keyboard input

  w_pressed:
    # function for when w is pressed, the 'throw' function
    # Should throw all bubbles being held straight up and line them up vertically, then check for a three in a row 
    # uses helper function get_lowest_bubble_grid_pos, which uses t0-3
    # uses helper function add_neighbors_to_bubbleset_recursive which uses pretty much all temps 
    # saves: s1 (bubbles held) s4 (held color)
    # temporaries t0 = bubble grid pos, t6 = grid position of upper bubbles, 
    # t7 = color checker also 3, t8 = lower/upper bound loop end condition, t9 = bubbles in a row
    
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      la $t8 CURRENT_GRID        # load current grid to t1 (bound for counting upper bubbles)
      li $t9 0                   # set t9 to 0 

      # end if not holding anything 
      beq $s1 $zero w_pressed_end      # if not holding any bubbles, end 

      # start a bubbleset (uses t0-2)
      jal push_bubbleset

      # check bubbles above lowest index for matches
      jal get_lowest_bubble_grid_pos      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
      addi $t6 $v0 0                      # set t6 to grid pos of lowest bubble 
        
      count_bubbles_above_loop:
        bne $v1 0 start_throwing_bubbles     # if there are no bubbles above, end 
        blt $t6 $t8 start_throwing_bubbles   # if the index goes out of bounds, end 
        lw $t7 0($t6)                        # load the color of the lowest bubble into t7
        bne $t7 $s4 start_throwing_bubbles   # if the lowest bubble doesn't match colors with the held bubble, irrelevant, end loop
        addi $t9 $t9 1                       # increment t9 by 1 
        addi $a0 $t6 0                       # set a0 to t6
        # jal add_to_bubbleset                 # add a0 to bubbleset 
        addi $t6 $t6 -28                     # decrement t6 to next row 
        j count_bubbles_above_loop
        

      #check how many bubbles to throw
      start_throwing_bubbles:
      addi $t8 $t8 388           # set out of bounds potential 
      jal get_lowest_bubble_grid_pos      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
      addi $t6 $v0 0             # set t6 to grid pos of lowest bubble 

      throw_bubble_loop:
        beq $s1 $zero throw_bubble_loop_end      # if not holding any bubbles, end 
        addi $t9 $t9 1           # increment t9 by 1
        addi $s1 $s1 -1          # decrement s1 by 1 
        addi $t6 $t6 28          # shift t6 to index of next row 
        addi $a0 $t6 0           # set a0 to t6
        # jal add_to_bubbleset     # add a0 to bubbleset
        bgt $t6 $t8 throw_bubble_loop    # if at the bottom of the grid, continue with the loop but do not draw anything new 
        sw $s4 0($t6)            # throw the bubble (store it in current grid)
        j throw_bubble_loop
      
      throw_bubble_loop_end:
        li $t7 3               # set t7 to 3
        bge $t9 $t7 pop_some_bubbles    # if 3 or more in a row are found, pop some bubbles 
        jal pop_last_bubbleset          # else, pop the last bubbleset we started 
        j w_pressed_end                 # jump to end 

      pop_some_bubbles:
        # the actual popping is handled by game loop... but adding horizontal is still needed
        jal get_lowest_bubble_grid_pos      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
        addi $a0 $v0 0                      # set a0 to grid pos of lowest bubble 
        jal add_neighbors_to_bubbleset_recursive    # add everything adjacent to bubblset 
        j w_pressed_end

      w_pressed_end:
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      j process_p2_inputs    # end keyboard input


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
      
      bne $v1 $zero grab_done #if there is no bubble in the column, exit

      lw  $t6 0($v0)            # get color of the lowest bubble
      
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
      lw  $t6 0($v0)                   # get xcolor of the current slot
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
  
      j process_p2_inputs    # end keyboard input
      
      

##############################################################################
 # Popping Bubble Functions
##############################################################################

# these functions deal with BUBBLES_TO_POP data object, which we will treat as a queue, call it bubblequeue
# BUBBLES_TO_POP is a queue, where each item is a set of grid indexes to pop with a pointer equal to Combo_time or below... call this set a bubbleset
# operates under the assumption that everything stored in a given bubbleset is greater than the pointer value (COMBO_TIME)
# consider this section a class containing methods to handle this strange queue... 
  # reset to reset everything
  # get_queue_beginning to return the index of the first zero, aka the start of the queue 
  # push to start a new bubbleset 
  # add to add to the last bubbleset in the queue 
  # pop_last_bubbleset to delete the last bubbleset from the bubblequeue 
  # decrement_all which will decrement every pointer by 1, then remove any that reach zero 
  # shift_all which shifts every grid pos value stored in the queue down by 1 row (+28)
  # is_in_bubblesqueue, returns true (1) if a given value is stored, false (0) otherwise 

reset_bubblequeue:
  # function to reset the bubblequeue
  # temporaries: t0 = BUBBLESQUEUE, t1 = end condition

  la $t0 PLAYER_1_BUBBLESQUEUE
  addi $t1 $t0 392
  reset_bubblesqueue_loop:
    sw $zero 0($t0)
    addi $t0 $t0 4
    bge $t0 $t1 end_clear_bubblequeue_loop
    j reset_bubblesqueue_loop
    
  end_clear_bubblequeue_loop:
  jr $ra 


get_queue_beginning:
  # function to return the start of the queue, aka the first zero
  # returns that value in v0 
  # temporaries: t0 = BUBBLESQUEUE, t1 = end condition, t2 = value

  la $t0 PLAYER_1_BUBBLESQUEUE
  addi $t1 $t0 392
  get_queue_beginning_loop:
    lw $t2 0($t0)                           # load the value at t2 in bubblequeue 
    beq $t2 $zero end_get_queue_beginning_loop   # return if found a zero 
    addi $t0 $t0 4                               # increment t4 
    bge $t0 $t1 end_clear_bubblequeue_loop       # if go out of bounds... there's an error, but end loop anyway 
    j get_queue_beginning_loop
    
  end_get_queue_beginning_loop:
    addi $v0 $t0 0             # set v0 to t0 
    jr $ra 


push_bubbleset:
  # function to start a new bubbleset 
  # calls helper function get_queue_beginning, which uses t0-2
  # temporaries: t0 = COMBO_TIME (ok to reuse)
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning    # get beginning of the queue into v0 
    lw $t0 COMBO_TIME
    sw $t0 0($v0)              # store combo time into the beginning of the stack 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 


add_to_bubbleset:
  # function to add to the bubbleset at the end of the queue 
  # takes input parameter a0 = grid pos being added 
  # calls helper function get_queue_beginning, which uses t0-2
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning    # get beginning of the queue into v0 
    sw $a0 0($v0)              # store current grid pos into the beginning of the stack 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 

pop_last_bubbleset:
  # function to delete the last bubbleset
  # calls helper function get_queue_beginning, which uses t0-2
  # temporaries: t0 = index, t1 = COMBO_TIME, t2 = value at index, t3 = BUBBLESQUEUE (should be redundant, just a backup really)
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning    # get beginning of the queue into v0 
    addi $t0 $v0 0             # set t0 to v0
    lw $t1 COMBO_TIME          # set t1 to combo time 
    la $t3 PLAYER_1_BUBBLESQUEUE   # set t3 to bubblesqueue 
    pop_last_bubbleset_loop:
      addi $t0 $t0 -4           # decrement t0 by 1 place
      lw $t2 0($t0)             # set t2 to the value at t0
      ble $t0 $t3 end_pop_last_bubbleset             # if the index is less than the endin
      blt $t2 $t1 finish_pop_last_bubbleset_loop     # if t2 (value at index) is less than or equal to combo time, finish loop
      sw $zero 0($t0)
      j pop_last_bubbleset_loop
      

    finish_pop_last_bubbleset_loop:
      sw $zero 0($t0)
    
    end_pop_last_bubbleset:
      
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 


decrement_all_bubblesets:
  # function to decrement all bubblesets by 1, and if the pointer reaches 1 then clear it out and move everything forward 
  # temporaries: t0 = BUBBLESQUEUE index, t1 = end condition, t2 = COMBOTIME/shiftindex, t3 = val at index, t4 = erase this section 
  # t5 = shift magnitude (relies on assumption that bubblesets are put into the queue in correct order, that is pointer[i] < pointer[i+1] for all i)
  # t6 = background color, t7 = curr grid upper bound 
  
    la $t0 PLAYER_1_BUBBLESQUEUE    # load bubblesqueue to t0
    addi $t1 $t0 392                # set end index to t1 
    lw $t2 COMBO_TIME               # set combotime to t2
    li $t4 0                        # set t4 to 0 
    li $t5 0                        # set t5 to 1 (because it will be incremented x times where x is the number of pops, + 1 for the pointer)
    lw $t6 BACKGROUND_COLOR         # set t6 to background color 
    la $t7 CURRENT_GRID             # set t7 to curr grid 
    addi $t7 $t7 392                # set t7 to upper bound 
    
    decrement_bubblesets_loop:
      bge $t0 $t1 decrement_bubblesets_loop_end     # if index reaches end loop condition, end loop 
      lw $t3 0($t0)                 # load the value at index t0 to t3
      bgt $t3 $t2 skip_decrement_pointer  # if the value is greater than combo val, so if it is not a pointer or a zero, skip decrement 
      ble $t3 $zero leave_bubbleval_alone #if the value is less than or equal to zero, skip decrement 
      j decrement_pointer      # else decrement  
      
      decrement_pointer:
          addi $t3 $t3 -1               # decrement the pointer
          sw $t3 0($t0)                 # store the decremented pointer 
          beq $t3 $zero set_erase_bubbleset_true     # if we just decremented pointer to zero, we will erase the next values until reaching a pointer (set t4 to 1)
          j set_erase_bubbleset_false    
          set_erase_bubbleset_true:
            li $t4 1                       # set t4 to 1 
            addi $t0 $t0 4                 # increment t0
            addi $t5 $t5 4                 # increment t5 
            j decrement_bubblesets_loop
          set_erase_bubbleset_false:
            li $t4 0
            addi $t0 $t0 4
            j decrement_bubblesets_loop
      skip_decrement_pointer:
        beq $t4 $zero leave_bubbleval_alone
        j erase_bubbleval
        erase_bubbleval:
          lw $t3 0($t0)
          # check if index is out of bounds 
          bge $t3 $t7 bubble_oob             # if t3 (value stored in bubble queue) is greater than upper limits of curr grid, we do not write anything to it 
            sw $t6 0($t3)
          bubble_oob: # out of bounds 
          sw $zero 0($t0)
          addi $t0 $t0 4
          addi $t5 $t5 4
          j decrement_bubblesets_loop
        leave_bubbleval_alone:
          addi $t0 $t0 4
          j decrement_bubblesets_loop
      
    decrement_bubblesets_loop_end:
     # at this point we have erased and decremented, now we need to shift
    
    la $t0 PLAYER_1_BUBBLESQUEUE                  # load bubblesque into t0 
    addi $t1 $t0 392                              # set t1 to end condition 
    shift_bubblesque_loop:
      add $t2 $t5 $t0                             # set t2 to the sum of t5 and t0 (t5 being the shift distance)
      bge $t2 $t1 end_shift_bubblesque_loop       # if t2 is out of bounds, end loop... technically should set the next few to zero, but it shouldn't get this far ever 
      lw $t3 0($t2)                               # set t3 to the value at t2 
      sw $t3 0($t0)                               # set bubbleval at t0 to the value stored in t3 
      addi $t0 $t0 4                              # increment t0 by 4 
      j shift_bubblesque_loop                     # loop 
      
    end_shift_bubblesque_loop:
      jr $ra 


shift_bubblesqueue_by_one:
  # function to shift everything stored down by 1 to avoid issues with shifting
  # temporaries: t0 = index of queue, t1 = end condition, t2 = combo time, t3 = stored value at index 

    la $t0 PLAYER_1_BUBBLESQUEUE    # load bubblesqueue to t0
    addi $t1 $t0 392                # set end index to t1 
    lw $t2 COMBO_TIME               # set combotime to t2

    shift_bubbles_by_one_loop:
      bge $t0 $t1 end_shift_bubbles_by_one_loop     # if index reaches end loop condition, end loop 
      lw $t3 0($t0)                     # load the value at index t0 to t3
      ble $t3 $t2 skip_bubble_shift     # if the value is less than or equal to combo val, so if it is a pointer or a zero, skip shift  
      j shift_bubble_down_one

      skip_bubble_shift:
        addi $t0 $t0 4                  # increment t0 
        j shift_bubbles_by_one_loop
        
      shift_bubble_down_one:
        lw $t3 0($t0)                   # load t3 to t0 
        addi $t3 $t3 28                 # add 28 to the value at t3 (shifting down a row)
        sw $t3 0($t0)                   # store updated value to bubblesqueue 
        addi $t0 $t0 4                  # increment t0 
        j shift_bubbles_by_one_loop
  
    end_shift_bubbles_by_one_loop:
        jr $ra 


is_in_bubblesqueue:
  # function to check if a given value (a0) is stored in the bubblesqueue
  # input: a0, somewhere in current_grid
  # output: v0, 0 if false, 1 if true 
  # temporaries t0 = index, t1 = end condition, t2 = stored value at index 

  la $t0 PLAYER_1_BUBBLESQUEUE   # set t0 to index 
  addi $t1 $t0 392               # set t1 to end condition 
  li $v0 0                       # set v0 to 0 
  check_bubblequeue_membership_loop:
    bge $t0 $t1 end_check_bubblequeue_loop
    lw $t2 0($t0)
    beq $t2 $a0 in_bubblesqueue_true
    addi $t0 $t0 4
    j check_bubblequeue_membership_loop

  in_bubblesqueue_true:
    li $v0 1                   # load 1 to v0 
    j end_check_bubblequeue_loop
      
  end_check_bubblequeue_loop:
  jr $ra 

  









###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################

 # PLAYER TWO SCRIPTS 


###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################


# TODO P2: IMPLEMENT GAME LOOP AND MAIN IN MAIN GAME LOOP (THEN DELETE THIS)

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
# Display Functions
##############################################################################


initialize_fool_2:
  # function to initialize the fool, including setting PLAYER_POS and PLAYER_BOUND_LEFT, PLAYER_BOUND_RIGHT so s0
  # temporaries: t0 = bitmap address, t1 = grid height, t2 = grid horizontal offset, t3 = column width

    lw $t0 ADDR_DSPL                  # load grid specifications 
    lw $t1 GRID_HEIGHT
    lw $t2 GRID_HORIZONTAL_OFFSET_2
    lw $t3 COLUMN_WIDTH
        
    add $s0 $t0 $t1                   # set s2 to bottom
    add $s0 $s0 $t2
    add $s0 $s0 $t3
    move $t0 $s0                      # set t0 to bottom 
    sw $t0 PLAYER_2_BOUND_LEFT        # set player1 bound left 
    addi $t0 $t0 96                   # center t0 
    addi $s0 $t0 0                    # set player pos 
    addi $t0 $t0 96                   # center t0 
    sw $t0 PLAYER_2_BOUND_RIGHT       # set player2 bound right 

    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal draw_fool_2                     # draw fool 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 



draw_fool_2:
  # function to draw the fool
  # input: s0 should store a valid player position, a3 is 0 for left hand up, 1 for otherwise
  # This should be along the row of GRID_HEIGHT, or slightly below
  # temporaries: t0 = address to draw to, t1 = fool pattern address
  # t2 = red, t3 = green, t4 = gold, t5 = face, t6 = color to write
  # t7 = 512 if left hand is up (a1 is 0), -512 if right hand is up
  # t8 = horizontal stop condition
  # t9 = vertical stop condition

  move $t0 $s0          # store starting address in t0
  move $t1 $s0          # store starting address in t1
  lw $t2 CLOWN_COLOR_RED        # store red in t2
  lw $t3 CLOWN_COLOR_GREEN      # store green in t3
  lw $t4 CLOWN_COLOR_GOLD       # store gold in t4
  lw $t5 CLOWN_COLOR_FACE       # store face in t5
  lw $t6 CLOWN_COLOR_GREEN      # store a green (random, doens't matter) in t6
  addi $t8 $t0 32               # set horizontal loop condition
  addi $t9 $t0 4096             # set vertical loop condition

  # check which hand is up
  li $t7 0                         # load 0 to t7
  beq $t7 $a3 fool_left_hand_up_2    # check if a3 is equal to 0
  li $t7 512                       # load 4 to t7
  j draw_fool_loop_2                 # jump to fool loop
  
  fool_left_hand_up_2:
    li $t7 -512                    # load -4 to t7
    j draw_fool_loop_2               # jump to fool loop 

    
  draw_fool_loop_2:
    # decide which color, if any, to draw

    # check reds
    move $t1 $s0
    addi $t1 $t1 20
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -8
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 1020
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red_2
    add $t1 $t1 $t7                  # add or subtract 512 depending on a1 
    beq $t1 $t0 set_fool_color_red_2
    sub $t1 $t1 $t7 
    addi $t1 $t1 524                 # (512 + 12), shift right 3 down one 
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_red_2
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_red_2

    # check greens 
    move $t1 $s0 
    addi $t1 $t1 8
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 -4
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 8
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 1028                  # down two, right one, 512 + 512 + 4
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green_2 
    sub $t1 $t1 $t7                   # subtract +- 512
    beq $t1 $t0 set_fool_color_green_2
    add $t1 $t1 $t7
    addi $t1 $t1 500                          # down one, back three (512 - 12)
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green_2
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_green_2 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_green_2 

    # check face
    move $t1 $s0
    addi $t1 $t1 1548         # down three, over three (512 * 3 + 4 * 3)
    beq $t1 $t0 set_fool_color_face_2 
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_face_2 

    # check bells 
    move $t1 $s0
    addi $t1 $t1 512
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 512
    beq $t1 $t0 set_fool_color_gold_2
    addi $t1 $t1 4
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 20
    # beq $t1 $t0 set_fool_color_gold
    addi $t1 $t1 4
    beq $t1 $t0 set_fool_color_gold_2
    addi $t1 $t1 -512
    # beq $t1 $t0 set_fool_color_gold







    j skip_fool_write_2        # if no color is found, skip to next iteration 

    set_fool_color_red_2:
      move $t6 $t2           # store red into t6
      j draw_fool_write_2      # go to the write section of the loop
    set_fool_color_green_2:
      move $t6 $t3           # store green into t6
      j draw_fool_write_2      # go to the write section of the loop
    set_fool_color_gold_2:
      move $t6 $t4           # store gold into t6
      j draw_fool_write_2      # go to the write section of the loop
    set_fool_color_face_2:
      move $t6 $t5           # store face into t6
      j draw_fool_write_2      # go to the write section of the loop
     
  
    draw_fool_write_2:
      sw $t6 0($t0)                                # write the selected color to $t0
      skip_fool_write_2:
      addi $t0 $t0 4                               # increment t0
      beq $t8 $t0 draw_fool_horizontal_loop_end_2    # check for horizontal end condition
      j draw_fool_loop_2                             # return to start of loop 

    draw_fool_horizontal_loop_end_2:
      addi $t0 $t0 480           # rest address to beginning of next line (512 - 32)
      addi $t8 $t8 512           # reset horizontal end condition to end of next line
      beq $t0 $t9 draw_fool_loop_end_2           # check vertical end condition
      j draw_fool_loop_2

    draw_fool_loop_end_2:
      jr $ra                    # return

erase_fool_2:
  
  # function to erase the fool
  # input: s2 should store a valid player position
  # This should be along the row of GRID_HEIGHT, or slightly below
  # temporaries: t0 = address to draw to
  # t6 = background color
  # t8 = horizontal stop condition
  # t9 = vertical stop condition


  move $t0 $s0          # store starting address in t0
  lw $t6 BACKGROUND_COLOR      # store background color
  addi $t8 $t0 32               # set horizontal loop condition
  addi $t9 $t0 4096             # set vertical loop condition

  erase_fool_loop_2:
      sw $t6 0($t0)                                # write the selected color to $t0
      addi $t0 $t0 4                               # increment t0
      beq $t8 $t0 erase_fool_horizontal_loop_end_2    # check for horizontal end condition
      j erase_fool_loop_2                            # return to start of loop 

    erase_fool_horizontal_loop_end_2:
      addi $t0 $t0 480           # rest address to beginning of next line (512 - 32)
      addi $t8 $t8 512           # reset horizontal end condition to end of next line
      beq $t0 $t9 erase_fool_loop_end_2           # check vertical end condition
      j erase_fool_loop_2

    erase_fool_loop_end_2:
      jr $ra                    # return

        
draw_border_2:
  # function to draw the border of the magical drop playing field
  # temporaries: 
  # t0: first column address, t1: second column address, t3: horizontal end condition, t4: vertical end condition 
  # t5: color, t6: horizontal grid offset, t7: grid width, t8: column width

  #load the temporaries
  lw $t0, ADDR_DSPL
  lw $t4, GRID_HEIGHT
  lw $t5, BORDER_COLOR
  lw $t6, GRID_HORIZONTAL_OFFSET_2
  lw $t7, GRID_WIDTH
  lw $t8, COLUMN_WIDTH
  add $t0, $t0, $t6        #set the first column address
  add $t1, $t8, $t7        #set the second column address
  add $t1, $t1, $t0        # ^
  add $t3, $t8, $t0        # set horizontal end condition based on col width
  add $t4, $t4, $t0        # set vertical end condition based on grid height
  

  border_loop_column_2:
      sw $t5, 0($t0)
      sw $t5, 0($t1)
      addi $t0, $t0, 4
      addi $t1, $t1, 4
      ble $t3, $t0, border_loop_horizontal_end_2
      j border_loop_column_2

    border_loop_horizontal_end_2:      
      addi $t0, $t0, 512         #reset column addresses to start of next line
      sub $t0, $t0, $t8
      addi $t1, $t1, 512         #reset column addresses to start of next line
      sub $t1, $t1, $t8
      addi $t3, $t3, 512         # increment the horizontal end condition
      ble $t4, $t0, border_loop_vertical_end_2
      j border_loop_column_2

  border_loop_vertical_end_2:
      jr $ra



update_board_2:
  # function to update the bitmap based on CURRENT_GRID_2
  # calls helper function draw bubble which uses t1, 4, 7-9
  # temporaries: t5 = grid template index, t6 = grid template loop end value
  # t2 = current grid color, t3 = current grid address
  
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 GRID_TEMPLATE_2       # load GRID_TEMPLATE to t5
    la $t3 CURRENT_GRID_2        # load CURRENT_GRID to t3 
    addi $t6 $t5 392           # set t6 to loop end condition


  
    update_board_loop_2:
        lw $a1 0($t3)          # store color of CURRENT_GRID in a1 (parameter for draw_bubble)
        lw $a0 0($t5)          # store values of GRID_TEMPLATE in a0 (parameter for draw_bubble)
        jal draw_bubble        # call draw_bubble
        addi $t5 $t5 4         # increment t5 by 4
        addi $t3 $t3 4         # increment t3 by 4
        beq $t5 $t6 update_board_loop_end_2          # check if loop is over
        j update_board_loop_2    # restart loop

    update_board_loop_end_2:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return 
  
        
fill_first_three_rows_random_2:
    # fills the first three rows with randomly colored bubbles
    # helper functions: calls get_random_color, which uses t0-3
    # only changes the values stored in current grid, nothing else
    # temporaries: t5 = Current grid index, t6 = loop end condition

    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 CURRENT_GRID_2        # set t5 to current grid 
    addi $t6 $t5 84            # set t6 to loop end condition

  
    random_fill_first_three_rows_loop_2:
        jal get_random_color   # call get_random_color
        sw $v0 0($t5)          # store the randomly generated color into CURRENT_GRID
        addi $t5 $t5 4         # increment t5 by 4
        beq $t5 $t6 random_fill_first_three_rows_loop_end_2          # check if loop is over
        j random_fill_first_three_rows_loop_2                        # restart loop

    random_fill_first_three_rows_loop_end_2:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return

fill_first_row_random_2:
    # fills the first singular row with randomly colored bubbles
    # helper functions: calls get_random_color, which uses t0-3
    # only changes the values stored in current grid, nothing else
    # temporaries: t5 = Current grid index, t6 = loop end condition

    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t5 CURRENT_GRID_2        # set t5 to current grid 
    addi $t6 $t5 28            # set t6 to loop end condition

  
    random_fill_first_row_loop_2:
        jal get_random_color   # call get_random_color
        sw $v0 0($t5)          # store the randomly generated color into CURRENT_GRID
        addi $t5 $t5 4         # increment t5 by 4
        beq $t5 $t6 random_fill_first_row_loop_end_2          # check if loop is over
        j random_fill_first_row_loop_2                        # restart loop

    random_fill_first_row_loop_end_2:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return


shift_down_by_one_2:
  # function to move everything in the current grid down by one row 
  # temporaries: t3 = address of bottom right corner of CURRENT_GRID, decremented by 4
  # t4 = address 2 rows above t3, t5 = color two rows above t3, t6 = loop end condition

    la $t3 CURRENT_GRID_2        # set t3 to current grid  
    addi $t6 $t3 28            # set t6 to loop end condition
    addi $t3 $t3 388           # set $t3 to bottom right
    
    shift_down_by_one_loop_2:
        addi $t4 $t3 -28       # set t4 to the address of the bubble one row above
        lw $t5 0($t4)          # set t5 to color of t4's bubble
        sw $t5 0($t3)          # set t3's bubble to t5 color (color of the bubble one row below)
        addi $t3 $t3 -4         # increment t3 by -4
        blt $t3 $t6 shift_down_by_one_loop_end_2          # check if loop is over
        j shift_down_by_one_loop_2    # restart loop

    shift_down_by_one_loop_end_2:
        jr $ra                   # return 


  

draw_arrows_2:
    # draws arrow based on player pos s2 going up until it hits a bubble in Current_grid
    # will draw arrows facing up or down depending on s1 (bubbles held)
    # uses helper functions get_fool_grid_pos and get_lowest_bubble_grid_pos, which use t0-3
    # temporaries: t9 = first block to draw arrows in, t8 = last block to draw arrows in
    
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_fool_grid_pos_2      # gets fool grid position into v0 
    addi $t9 $v0 0             # set t9 to start grid pos 
    jal get_lowest_bubble_grid_pos_2    # sets v0 to position of the lowest bubble, v1 to 1 if none is found and 0 if it exists
    addi $t8 $v0 0             # set t8 to end grid pos 
    sub $t8 $t8 $v1            # if a bubble is found, this does nothing. If no bubble is found, then we decrement the ending index by one 

    draw_arrows_loop_2:
      ble $t9 $t8 end_draw_arrows_2        # if the index we want to draw arrows to is above or at the ending index, we end the loop
      addi $a0 $t9 0                     # set a0 to the grid pos we want to draw to 
      jal draw_arrow_block_2               # draws a block of arrows 
      addi $t9 $t9 -28                   # decrement grid pos down a row
      j draw_arrows_loop_2
    
    end_draw_arrows_2:
    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 


draw_arrow_block_2:
    # function to fill a given block with arrows 
    # takes parameters a0 = block of current grid to draw to
    
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_pixel_from_grid    # stores the top left pixel value of a0 into v0 (assume a0 is already declared as input)
    addi $a0 $v0 12            # centers a0 to top center of the given block 
    addi $a0 $a0 512          # moves the index down two rows 
    jal draw_arrow_2             # draws an arrow at the given position
    addi $a0 $a0 2048          # moves the index down three rows 
    jal draw_arrow_2             # draws an arrow at the given position

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 

draw_arrow_2:
  # helper function to draw a single arrow centered at a given address of the bitmap (left centered, i.e. in 0-31, would be 15)
  # takes inputs: a0 = address of the centermost top pixel
  # temporaries: t0 = address to write to, t1 = color, t2 up/down (-512 for pointing down, 0 for pointing up)
  # saves: s1, checks if holding
  # PRECONDITION cannot be outside valid range or gonna get errors (valid range for bitmap)

  addi $t0 $a0 0              # set to to starting address 
  lw $t1 COLOR_ARROW         # set t1 to arrow color 


  # check if going up or down
  bne $s3 0 draw_arrow_pointing_up
  li $t2 -512
  j start_drawing_arrow_2

  draw_arrow_pointing_up_2:
  li $t2 0
  j start_drawing_arrow_2

  start_drawing_arrow_2:
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




# ##############################################################################
# # Helper Functions
# ##############################################################################
   

  build_grid_template_2:
    # function to build the grid template (see .data for details) and current grid
    # temporaries: $t0 = address to be stored, $t1 = horizontal loop condition, $t2 = vertical loop condition, t3 = GRID_TEMPLATE, t4 = CURRENT_GRID
    # t5 = background color
    # $t8 = grid horizontal offset, t9 = column width

    lw $t0 ADDR_DSPL                  # store ADDR_DSPL in t0
    lw $t8 GRID_HORIZONTAL_OFFSET_2     # store GRID_HORIZONTAL_OFFSET in t8
    lw $t9 COLUMN_WIDTH               # store COLUMN_WIDTH in t9
    add $t0 $t0 $t8                   # add offset and column width to initial address to obtain start of grid template
    add $t0 $t0 $t9                   
    addi $t1 $t0 224                  # set t1 to initial horizontal loop condition
    addi $t2 $t0 53744                # set t2 to vertical loop condition
    la $t3 GRID_TEMPLATE_2              # set t3 to GRID_TEMPLATE address
    la $t4 CURRENT_GRID_2               # set t4 to CURRENT_GRID
    lw $t5 BACKGROUND_COLOR           # set t5 to background color 

    grid_builder_loop_2:
      sw $t0 0($t3)                   # store t0 in GRID_TEMPLATE through t3
      sw $t5 0($t4)                   # store background_color in CURRENT GRID
      addi $t0 $t0 32                 # increment t0 by 32
      addi $t3 $t3 4                  # increment t3 by 4
      addi $t4 $t4 4                  # increment t4 by 4 
      beq $t0 $t1 horizontal_grid_builder_loop_end_2        # check horizontal loop condition
      j grid_builder_loop_2                                 # jump to start of loop 
      
      horizontal_grid_builder_loop_end_2:
        addi $t0 $t0 -224              # increment t0 back to start of row
        addi $t0 $t0 4096              # increment t0 down 8 rows
        addi $t1 $t1 4096              # increment t1, horizontal loop condition
        bgt $t0 $t2 grid_builder_loop_end_2                   # check vertical loop condition
        j grid_builder_loop_2           # jump to start of loop
      grid_builder_loop_end_2:
        jr $ra                        # return 


get_fool_grid_pos_2:
  # helper function to return the bottommost index of the column that the fool is standing in from CURRENT_GRID
  # returns that value (364, 368, 372, 376, 380, 384, 388) in v0
  # temporaries: t0 = potential positions, t1 current grid 

  la $t1 CURRENT_GRID_2

  #could be implemented with a loop, writing it out is faster though, involves shifting and math (could optimize this later though)
  lw $t0 PLAYER_2_BOUND_LEFT         # set left position 
  beq $s0 $t0 get_pos_0_2              # check through all possible positions ... 
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_1_2
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_2_2
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_3_2
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_4_2
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_5_2
  addi $t0 $t0 32
  beq $s0 $t0 get_pos_6_2
  addi $t0 $t0 32

  get_pos_0_2:
    addi $v0 $t1 364       # set value to appropriate position
    jr $ra                 # return
  get_pos_1_2:
    addi $v0 $t1 368       # set value to appropriate position
    jr $ra                 # return
  get_pos_2_2:
    addi $v0 $t1 372       # set value to appropriate position
    jr $ra                 # return
  get_pos_3_2:
    addi $v0 $t1 376       # set value to appropriate position
    jr $ra                 # return
  get_pos_4_2:
    addi $v0 $t1 380       # set value to appropriate position
    jr $ra                 # return
  get_pos_5_2:
    addi $v0 $t1 384       # set value to appropriate position
    jr $ra                 # return
  get_pos_6_2:
    addi $v0 $t1 388       # set value to appropriate position
    jr $ra                 # return



get_lowest_bubble_grid_pos_2:
  # function to fetch the grid position of the lowest bubble above the fool 
  # returns that value in v0, returns 0 in v1 if there is a bubble and 1 if none is found, returns pixel value in v2
  # temporaries: t0 = grid color checked t1 = background color t2 = grid color stored, t3 = min val 

  # push ra to stack
  addi $sp, $sp, -4          # moves stack pointer a word
  sw $ra 0($sp)              # push a word onto the stack

  jal get_fool_grid_pos_2      # fetch the grid position of the fool into v0
  lw $t1 BACKGROUND_COLOR    # store background color into t1 
  la $t3 CURRENT_GRID_2        # load current grid to t3 
  lw $t3 0($t3)              # store minimum value of current_grid in t3
  addi $t0 $v0 0             # set t0 to grid position above the fool 

  check_lowest_bubble_loop_2:
    lw $t2 0($t0)            # load the color stored in current_grid into t2
    bne $t1 $t2 return_lowest_bubble_2         # if the value is not the background color, return the position 
    addi $t0 $t0 -28         # shift the place we're checking down by 28 
    blt $t0 $t3 return_empty_lowest_bubble_2   # check if it's out of bounds 
    j check_lowest_bubble_loop_2

  return_lowest_bubble_2:
    li $v1 0                # set v1 to 0, indicating we found a bubble (or we did not find nothing)
    addi $v0 $t0 0          # set v0 to value that has a bubble 
    j end_lowest_bubble_2
  
  return_empty_lowest_bubble_2:
    addi $t0 $t0 28         # shift the index back to the top row
    li $v1 1                # set v1 to 1, meaning no bubble is found (or emptiness was found)
    addi $v0 $t0 0          # set v0 to top row above the fool 
    j end_lowest_bubble_2
    

  end_lowest_bubble_2:
    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 

    
is_in_left_column_2:
  # helper function checking if a given grid position is in the left column of the bitmap
  # could be implemented more elegantly with math, but seems more efficient to brute force it 
  # takes input parameter a0 = index being checked
  # outputs v0, which is 0 if not in left column, 1 if yes in left column
  # temporaries: t3 = address checking, t4 = ending loop condition

  li $v0 0           # set v0 to 0 
  la $t3 CURRENT_GRID_2
  addi $t4 $t3 392  # set to loop end condition 
  is_in_left_column_loop_2:
    bge $t3 $t4 in_left_column_return_false_2      # if index goes out of bounds, end loop 
    beq $a0 $t3 in_left_column_return_true_2       # if parameter is equal to index being checked, return true 
    addi $t3 $t3 28                              # increment t3 down a column 
    j is_in_left_column_loop_2
    

  in_left_column_return_true_2:
    li $v0 1     # set v0 to 1 
  in_left_column_return_false_2:
    jr $ra       # return 


is_in_right_column_2:
  # helper function checking if a given grid position is in the right column of the bitmap
  # could be implemented more elegantly with math, but seems more efficient to brute force it 
  # takes input parameter a0 = index being checked
  # outputs v0, which is 0 if not in left column, 1 if yes in left column
  # temporaries: t3 = address checking, t4 = ending loop condition

  li $v0 0           # set v0 to 0 
  la $t3 CURRENT_GRID_2
  addi $t4 $t3 392  # set to loop end condition 
  addi $t3 $t3 24   # set t3 to top of right column 
  is_in_right_column_loop_2:
    bge $t3 $t4 in_right_column_return_false_2      # if index goes out of bounds, end loop 
    beq $a0 $t3 in_right_column_return_true_2       # if parameter is equal to index being checked, return true 
    addi $t3 $t3 28                              # increment t3 down a column 
    j is_in_right_column_loop_2
    

  in_right_column_return_true_2:
    li $v0 1     # set v0 to 1 
  in_right_column_return_false_2:
    jr $ra       # return 



add_neighbors_to_bubbleset_recursive_2:
  # function to add neighbors of a given bubble to the last bubbleset, which recurses until no neighbors of the same color are adjacent 
  # takes input a0 = bubble to check neighbors (which should already be in the bubbleset)
  # uses helper function is_in_bubblesqueue, which takes a0 input as a grid position and returns v0 as 0 if false, 1 if true (0 if not in, 1 if in), also uses temps 0-2
  # uses helper function add_to_bubbleset, which uses t0-2 and takes input parameter a0 = grid pos being added 
  # uses helper functions is_in_left_column and is_in_right_column, which takes input parameter a0 = grid position being checked, returns v0 = 0 if not in col, 1 if in  
  # temporaries t9 = neighbor address, t8 = bound to check, t7 = main color, t6 = neighbor color 
  
    # push ra to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $t8 CURRENT_GRID_2        # set t8 to current grid 
    addi $t9 $a0 0             # set t9 to address to check 
    lw $t7 0($t9)              # load the color of a0 into t7 

    recurse_below_2:    # in hindsight, this naming convention is slightly misleading... below in memory, though it's checking the position above in the bitmap
    addi $t9 $t9 -28           # check below 
    la $t8 CURRENT_GRID_2        # set t8 to current grid 
    blt $t9 $t8 recurse_above_2  # if out of bounds, end
    lw $t6 0($t9)              # load the neighbor bottom color to t6 
    bne $t6 $t7 recurse_above_2  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue_2     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_above_2    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset_2       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive_2

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_above_2

    recurse_above_2:         # position above in memory, below in bitmap
    addi $t9 $t9 56        # move t9 up two rows, to check the upper neighbor 
    la $t8 CURRENT_GRID_2        # set t8 to current grid 
    addi $t8 $t8 388       # set t8 to lower bound (spatially, upper bound numerically)
    bgt $t9 $t8 recurse_left_2  # if out of bounds, end
    lw $t6 0($t9)              # load the neighbor upper color to t6 
    bne $t6 $t7 recurse_left_2  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue_2     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_left_2    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset_2       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive_2

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_left_2

    recurse_left_2:
    addi $t9 $t9 -32        # move t9 up one row then to the left, to check the left neighbor...  
    la $t8 CURRENT_GRID_2        # set t8 to current grid 
    blt $t9 $t8 recurse_right_2  # if out of bounds, end
    addi $a0 $t9 0          # set a0 to t9 
    jal is_in_right_column_2  # set v0 to 0 if not in right col, 1 if is in right col 
    bne $v0 $zero recurse_right_2     # if t9 is in right column, then t9 + 4 is in left column, so end recursion (so check if v0 doesn't equal 0)
    lw $t6 0($t9)              # load the neighbor upper color to t6 
    bne $t6 $t7 recurse_right_2  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue_2     # check if a0 is in bubblesqueue 
    beq $v0 1 recurse_right_2    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset_2       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive_2

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j recurse_right_2

  recurse_right_2:
    addi $t9 $t9 8        # move t9 right two, shifting from left neighbor to right neighbor   
    la $t8 CURRENT_GRID_2     # set t8 to lower bound
    addi $t8 $t8 392        # set t8 to upper bound 
    bge $t9 $t8 finish_recursing_2  # if out of bounds, end
    addi $a0 $t9 0          # set a0 to t9 
    jal is_in_left_column_2  # set v0 to 0 if not in left col, 1 if is in left col 
    bne $v0 $zero finish_recursing_2     # if t9 is in right column, then t9 + 4 is in left column, so end recursion (so check if v0 doesn't equal 0)
    lw $t6 0($t9)              # load the neighbor right color to t6 
    bne $t6 $t7 finish_recursing_2  # if colors not equal, end 
    # else, check if neighbor in bubbleset 
    addi $a0 $t9 0             # set a0 to bottom neighbor 
    jal is_in_bubblesqueue_2     # check if a0 is in bubblesqueue 
    beq $v0 1 finish_recursing_2    # if it is already in bubbleset, end 
    # else, we have a bubble that is same color and not already in the bubbleset, so we add then recurse 
    jal add_to_bubbleset_2       # add bottom neighbor to bubbleset (we already set a0 to t9)
    # push t9 to stack
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $t9 0($sp)              # push a word onto the stack

    jal add_neighbors_to_bubbleset_recursive_2

    # pull t9 from stack 
    lw $t9, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4
    j finish_recursing_2

    finish_recursing_2:

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra                   # return 


check_game_over_2:
  # function to check of the game ends
  # temporaries: t3 = bottom right, t4 = background color, t5 = addressed color, t6 = loop end condition
  
    la $t3 CURRENT_GRID_2        # load current grid to t3 
    addi $t6 $t3 364           # set t6 to loop end condition
    addi $t3 $t3 388           # set $t3 to bottom right
    lw $t4 BACKGROUND_COLOR    # set t4 to background color
    
    check_game_over_loop_2:
        lw $t5 0($t3)          # set t5 to color of t3's bubble
        bne $t5 $t4 check_game_over_is_over_2       # if the color is not background, game is over
        return_to_check_game_over_loop_2:           # for when we check bubblequeue membership 
        addi $t3 $t3 -4        # increment t3 by -4
        blt $t3 $t6 check_game_over_loop_end_2          # check if loop is over
        j check_game_over_loop_2    # restart loop

    check_game_over_loop_end_2:
        jr $ra                   # return 

    check_game_over_is_over_2:
      # first check if index is in bubblesqueue 
      addi $a0 $t3 0            # set a0 to t3 
      
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal is_in_bubblesqueue_2     # stores into v0 0 if a0 is not in bubblequeue, 1 if it is

      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      beq $v0 $zero check_game_over_is_over_for_real_2
      j return_to_check_game_over_loop_2

      check_game_over_is_over_for_real_2:
      jal shift_down_by_one_2
      j game_over
      


# ##############################################################################
# # Input Functions
# ##############################################################################

# called in the main check_input function

    j_pressed:
      # function to handle when left key is pressed
      # moves player_pos left by 32, if does not exceed the bound
      # temporaries: t0 = s2 - 32, = player pos - 32, t1 = left bound

      lw $t1 PLAYER_2_BOUND_LEFT    # set t1 to left bound 
      addi $t0 $s0 -32              # set t0 to playerpos - 32
      bge $t0 $t1 move_fool_left_2    # check if moving left takes the fool beyond the border
      j end_check_keyboard_input    # end keyboard input
      move_fool_left_2:
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal erase_fool_2
      addi $s0 $s0 -32              # move player pos one unit left
      jal draw_fool_2
      
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      j end_check_keyboard_input    # end keyboard input 

    l_pressed:
      # function to handle when right key is pressed
      # moves player_pos right by 32, if does not exceed the bound
      # temporaries: t0 = s2 + 32, = player pos + 32, t1 = right bound 

      lw $t1 PLAYER_2_BOUND_RIGHT   # set right bound to t1 
      addi $t0 $s0 32               # set t0 to playerpos + 32
      ble $t0 $t1 move_fool_right_2   # check if moving left takes the fool beyond the border
      j end_check_keyboard_input    # end keyboard input
      move_fool_right_2:
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal erase_fool_2
      addi $s0 $s0 32              # move player pos one unit left
      jal draw_fool_2
      
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

      j end_check_keyboard_input    # end keyboard input 

  i_pressed:
    # function for when up is pressed, the 'throw' function
    # Should throw all bubbles being held straight up and line them up vertically, then check for a three in a row 
    # uses helper function get_lowest_bubble_grid_pos, which uses t0-3
    # saves: s1 (bubbles held) s4 (held color)
    # temporaries t0 = bubble grid pos, t6 = grid position of upper bubbles, 
    # t7 = color checker also 3, t8 = lower/upper bound loop end condition, t9 = bubbles in a row
    
      # push ra to stack
      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      la $t8 CURRENT_GRID_2        # load current grid to t1 (bound for counting upper bubbles)
      li $t9 0                   # set t9 to 0 

      # end if not holding anything 
      beq $s3 $zero up_arrow_pressed_end      # if not holding any bubbles, end 

      # start a bubbleset (uses t0-2)
      jal push_bubbleset_2

      # check bubbles above lowest index for matches
      jal get_lowest_bubble_grid_pos_2      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
      addi $t6 $v0 0                      # set t6 to grid pos of lowest bubble 
        
      count_bubbles_above_loop_2:
        bne $v1 0 start_throwing_bubbles_2     # if there are no bubbles above, end 
        blt $t6 $t8 start_throwing_bubbles_2   # if the index goes out of bounds, end 
        lw $t7 0($t6)                        # load the color of the lowest bubble into t7
        bne $t7 $s7 start_throwing_bubbles_2   # if the lowest bubble doesn't match colors with the held bubble, irrelevant, end loop
        addi $t9 $t9 1                       # increment t9 by 1 
        addi $a0 $t6 0                       # set a0 to t6
        # jal add_to_bubbleset_2                # add a0 to bubbleset 
        addi $t6 $t6 -28                     # decrement t6 to next row 
        j count_bubbles_above_loop_2
        

      #check how many bubbles to throw
      start_throwing_bubbles_2:
      addi $t8 $t8 388           # set out of bounds potential 
      jal get_lowest_bubble_grid_pos_2      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
      addi $t6 $v0 0             # set t6 to grid pos of lowest bubble 

      throw_bubble_loop_2:
        beq $s3 $zero throw_bubble_loop_end_2      # if not holding any bubbles, end 
        addi $t9 $t9 1           # increment t9 by 1
        addi $s3 $s3 -1          # decrement s1 by 1 
        addi $t6 $t6 28          # shift t6 to index of next row 
        addi $a0 $t6 0           # set a0 to t6
        # jal add_to_bubbleset_2     # add a0 to bubbleset
        bgt $t6 $t8 throw_bubble_loop_2    # if at the bottom of the grid, continue with the loop but do not draw anything new 
        sw $s7 0($t6)            # throw the bubble (store it in current grid)
        j throw_bubble_loop_2
      
      throw_bubble_loop_end_2:
        li $t7 3               # set t7 to 3
        bge $t9 $t7 pop_some_bubbles_2    # if 3 or more in a row are found, pop some bubbles 
        jal pop_last_bubbleset_2          # else, pop the last bubbleset we started 
        j up_arrow_pressed_end                 # jump to end 

      pop_some_bubbles_2:
        # this adds everything to the bubbleset, including neighbors 
        jal get_lowest_bubble_grid_pos_2      # returns grid pos in v0, returns 0 in v1 if there is a bubble 
        addi $a0 $v0 0                      # set a0 to grid pos of lowest bubble 
        jal add_neighbors_to_bubbleset_recursive_2    # add everything adjacent to bubblset 

        j up_arrow_pressed_end

      up_arrow_pressed_end:
      # pull ra from stack 
      lw $ra, 0($sp)           # load old ra to new $ra from stack
      addi $sp, $sp, 4         # moves the stack pointer up 4

    j end_check_keyboard_input    # end keyboard input 


  k_pressed:
    # TODO: implement grab control 

      # v0 is current grid position(column * 7)
      # v1 is 0 if there is a bubble in the column
      # $t4 is background color
      # $t5 is grid_base
      # $t6 is lowest bubble color

      addi $sp, $sp, -4          # moves stack pointer a word
      sw $ra 0($sp)              # push a word onto the stack

      jal get_lowest_bubble_grid_pos_2
      
      bne $v1 $zero grab_done_2 #if there is no bubble in the column, exit

      lw  $t6 0($v0)            # get color of the lowest bubble
      
      bne $s3 $zero check_colors_match_2 # if already holding a bubble, check if colors match

      # if no bubbles are held
      addi $s7 $t6 0            # set grabbing color to color of lowest bubble
      j grab_setup_2 # if not holding a bubble, grab bubbles

    check_colors_match_2:
      bne $t6 $s7 grab_done_2    #  if, different color, exit

    grab_setup_2:
      lw $t4 BACKGROUND_COLOR          # t4 = background color
      la $t5 CURRENT_GRID_2            # t5 = grid base (upper bound)

    # goes up to see if others in column touching are same color
    grab_loop_2:
      lw  $t6 0($v0)                   # get xcolor of the current slot
      bne $t6 $s7 grab_done_2            # if color does not match current color, exit
      sw  $t4 0($v0)                   # clear the slot
      addi $s3 $s3 1                   # register one more bubble held
      addi $v0 $v0 -28                 # go one row up
      blt $v0 $t5 grab_done_2            # if past the top of the grid, exit
      j grab_loop_2

      # loads ra to be ra of caller of loop and not get_lowest_bubble, i.e. exit
      grab_done_2:
        # pull ra from stack 
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
  
        j end_check_keyboard_input    # end keyboard input
      
      

# ##############################################################################
#  # Popping Bubble Functions
# ##############################################################################

# # these functions deal with BUBBLES_TO_POP data object, which we will treat as a queue, call it bubblequeue
# # BUBBLES_TO_POP is a queue, where each item is a set of grid indexes to pop with a pointer equal to Combo_time or below... call this set a bubbleset
# # operates under the assumption that everything stored in a given bubbleset is greater than the pointer value (COMBO_TIME)
# # consider this section a class containing methods to handle this strange queue... 
#   # reset to reset everything
#   # get_queue_beginning to return the index of the first zero, aka the start of the queue 
#   # push to start a new bubbleset 
#   # add to add to the last bubbleset in the queue 
#   # pop_last_bubbleset to delete the last bubbleset from the bubblequeue 
#   # decrement_all which will decrement every pointer by 1, then remove any that reach zero 
#   # shift_all which shifts every grid pos value stored in the queue down by 1 row (+28)
#   # is_in_bubblesqueue, returns true (1) if a given value is stored, false (0) otherwise 

reset_bubblequeue_2:
  # function to reset the bubblequeue
  # temporaries: t0 = BUBBLESQUEUE, t1 = end condition

  la $t0 PLAYER_2_BUBBLESQUEUE
  addi $t1 $t0 392
  reset_bubblesqueue_loop_2:
    sw $zero 0($t0)
    addi $t0 $t0 4
    bge $t0 $t1 end_clear_bubblequeue_loop_2
    j reset_bubblesqueue_loop_2
    
  end_clear_bubblequeue_loop_2:
  jr $ra 


get_queue_beginning_2:
  # function to return the start of the queue, aka the first zero
  # returns that value in v0 
  # temporaries: t0 = BUBBLESQUEUE, t1 = end condition, t2 = value

  la $t0 PLAYER_2_BUBBLESQUEUE
  addi $t1 $t0 392
  get_queue_beginning_loop_2:
    lw $t2 0($t0)                           # load the value at t2 in bubblequeue 
    beq $t2 $zero end_get_queue_beginning_loop_2   # return if found a zero 
    addi $t0 $t0 4                               # increment t4 
    bge $t0 $t1 end_clear_bubblequeue_loop_2       # if go out of bounds... there's an error, but end loop anyway 
    j get_queue_beginning_loop_2
    
  end_get_queue_beginning_loop_2:
    addi $v0 $t0 0             # set v0 to t0 
    jr $ra 


push_bubbleset_2:
  # function to start a new bubbleset 
  # calls helper function get_queue_beginning, which uses t0-2
  # temporaries: t0 = COMBO_TIME (ok to reuse)
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning_2    # get beginning of the queue into v0 
    lw $t0 COMBO_TIME
    sw $t0 0($v0)              # store combo time into the beginning of the stack 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 


add_to_bubbleset_2:
  # function to add to the bubbleset at the end of the queue 
  # takes input parameter a0 = grid pos being added 
  # calls helper function get_queue_beginning, which uses t0-2
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning_2    # get beginning of the queue into v0 
    sw $a0 0($v0)              # store combo time into the beginning of the stack 

    # pull ra from stack 
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 

pop_last_bubbleset_2:
  # function to delete the last bubbleset
  # calls helper function get_queue_beginning, which uses t0-2
  # temporaries: t0 = index, t1 = COMBO_TIME, t2 = value at index, t3 = BUBBLESQUEUE (should be redundant, just a backup really)
  
    # push ra onto stack 
    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    jal get_queue_beginning_2    # get beginning of the queue into v0 
    addi $t0 $v0 0             # set t0 to v0
    lw $t1 COMBO_TIME          # set t1 to combo time 
    la $t3 PLAYER_2_BUBBLESQUEUE   # set t3 to bubblesqueue 
    pop_last_bubbleset_loop_2:
      addi $t0 $t0 -4           # decrement t0 by 1 place
      lw $t2 0($t0)             # set t2 to the value at t0
      ble $t0 $t3 end_pop_last_bubbleset_2             # if the index is less than the endin
      blt $t2 $t1 finish_pop_last_bubbleset_loop_2     # if t2 (value at index) is less than or equal to combo time, finish loop
      sw $zero 0($t0)
      j pop_last_bubbleset_loop_2
      

    finish_pop_last_bubbleset_loop_2:
      sw $zero 0($t0)
    
    end_pop_last_bubbleset_2:
      
    lw $ra, 0($sp)           # load old ra to new $ra from stack
    addi $sp, $sp, 4         # moves the stack pointer up 4

    jr $ra 


decrement_all_bubblesets_2:
  # function to decrement all bubblesets by 1, and if the pointer reaches 1 then clear it out and move everything forward 
  # temporaries: t0 = BUBBLESQUEUE index, t1 = end condition, t2 = COMBOTIME/shiftindex, t3 = val at index, t4 = erase this section 
  # t5 = shift magnitude (relies on assumption that bubblesets are put into the queue in correct order, that is pointer[i] < pointer[i+1] for all i)
  # t6 = background color, t7 = curr grid upper bound 
  
    la $t0 PLAYER_2_BUBBLESQUEUE    # load bubblesqueue to t0
    addi $t1 $t0 392                # set end index to t1 
    lw $t2 COMBO_TIME               # set combotime to t2
    li $t4 0                        # set t4 to 0 
    li $t5 0                        # set t5 to 1 (because it will be incremented x times where x is the number of pops, + 1 for the pointer)
    lw $t6 BACKGROUND_COLOR         # set t6 to background color 
    la $t7 CURRENT_GRID_2             # set t7 to curr grid 
    addi $t7 $t7 392                # set t7 to upper bound 
    
    decrement_bubblesets_loop_2:
      bge $t0 $t1 decrement_bubblesets_loop_end_2     # if index reaches end loop condition, end loop 
      lw $t3 0($t0)                 # load the value at index t0 to t3
      bgt $t3 $t2 skip_decrement_pointer_2  # if the value is greater than combo val, so if it is not a pointer or a zero, skip decrement 
      ble $t3 $zero leave_bubbleval_alone_2 # if the value is less than or equal to zero, skip decrement 
      j decrement_pointer_2      # else decrement  
      
      decrement_pointer_2:
          addi $t3 $t3 -1               # decrement the pointer
          sw $t3 0($t0)                 # store the decremented pointer 
          beq $t3 $zero set_erase_bubbleset_true_2     # if we just decremented pointer to zero, we will erase the next values until reaching a pointer (set t4 to 1)
          j set_erase_bubbleset_false_2  
          set_erase_bubbleset_true_2:
            li $t4 1                       # set t4 to 1 
            addi $t0 $t0 4                 # increment t0
            addi $t5 $t5 4                 # increment t5 
            j decrement_bubblesets_loop_2
          set_erase_bubbleset_false_2:
            li $t4 0
            addi $t0 $t0 4
            j decrement_bubblesets_loop_2
      skip_decrement_pointer_2:
        beq $t4 $zero leave_bubbleval_alone_2
        j erase_bubbleval_2
        erase_bubbleval_2:
          lw $t3 0($t0)
          # check if index is out of bounds 
          bge $t3 $t7 bubble_oob_2             # if t3 (value stored in bubble queue) is greater than upper limits of curr grid, we do not write anything to it 
            sw $t6 0($t3)
          bubble_oob_2: # out of bounds 
          sw $zero 0($t0)
          addi $t0 $t0 4
          addi $t5 $t5 4
          j decrement_bubblesets_loop_2
        leave_bubbleval_alone_2:
          addi $t0 $t0 4
          j decrement_bubblesets_loop_2
      
    decrement_bubblesets_loop_end_2:
     # at this point we have erased and decremented, now we need to shift
    
    la $t0 PLAYER_2_BUBBLESQUEUE                  # load bubblesque into t0 
    addi $t1 $t0 392                              # set t1 to end condition 
    shift_bubblesque_loop_2:
      add $t2 $t5 $t0                             # set t2 to the sum of t5 and t0 (t5 being the shift distance)
      bge $t2 $t1 end_shift_bubblesque_loop_2       # if t2 is out of bounds, end loop... technically should set the next few to zero, but it shouldn't get this far ever 
      lw $t3 0($t2)                               # set t3 to the value at t2 
      sw $t3 0($t0)                               # set bubbleval at t0 to the value stored in t3 
      addi $t0 $t0 4                              # increment t0 by 4 
      j shift_bubblesque_loop_2                    # loop 
      
    end_shift_bubblesque_loop_2:
      jr $ra 


shift_bubblesqueue_by_one_2:
  # function to shift everything stored down by 1 to avoid issues with shifting
  # temporaries: t0 = index of queue, t1 = end condition, t2 = combo time, t3 = stored value at index 

    la $t0 PLAYER_2_BUBBLESQUEUE    # load bubblesqueue to t0
    addi $t1 $t0 392                # set end index to t1 
    lw $t2 COMBO_TIME               # set combotime to t2

    shift_bubbles_by_one_loop_2:
      bge $t0 $t1 end_shift_bubbles_by_one_loop_2     # if index reaches end loop condition, end loop 
      lw $t3 0($t0)                     # load the value at index t0 to t3
      ble $t3 $t2 skip_bubble_shift_2     # if the value is less than or equal to combo val, so if it is a pointer or a zero, skip shift  
      j shift_bubble_down_one_2

      skip_bubble_shift_2:
        addi $t0 $t0 4                  # increment t0 
        j shift_bubbles_by_one_loop_2
        
      shift_bubble_down_one_2:
        lw $t3 0($t0)                   # load t3 to t0 
        addi $t3 $t3 28                 # add 28 to the value at t3 (shifting down a row)
        sw $t3 0($t0)                   # store updated value to bubblesqueue 
        addi $t0 $t0 4                  # increment t0 
        j shift_bubbles_by_one_loop_2
  
    end_shift_bubbles_by_one_loop_2:
        jr $ra 


is_in_bubblesqueue_2:
  # function to check if a given value (a0) is stored in the bubblesqueue
  # input: a0, somewhere in current_grid
  # output: v0, 0 if false, 1 if true 
  # temporaries t0 = index, t1 = end condition, t2 = stored value at index 

  la $t0 PLAYER_2_BUBBLESQUEUE   # set t0 to index 
  addi $t1 $t0 392               # set t1 to end condition 
  li $v0 0                       # set v0 to 0 
  check_bubblequeue_membership_loop_2:
    bge $t0 $t1 end_check_bubblequeue_loop_2
    lw $t2 0($t0)
    beq $t2 $a0 in_bubblesqueue_true_2
    addi $t0 $t0 4
    j check_bubblequeue_membership_loop_2

  in_bubblesqueue_true_2:
    li $v0 1                   # load 1 to v0 
    j end_check_bubblequeue_loop_2
      
  end_check_bubblequeue_loop_2:
  jr $ra 

  