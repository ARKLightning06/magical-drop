################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Andrew Koes, 1012691482
# Student 2: Name, Student Number (if applicable)
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
    .word 1000

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
  # s0 = GRID_TEMPLATE
  # s1 = CURRENT_GRID
  # s2 = CHARACTER_POS
  # s3 = CHARACTER_BOUND_LEFT
  # s4 = CHARACTER_BOUND_RIGHT
  # s5 = IS_PAUSED 

##############################################################################
# Main
##############################################################################

	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal initialize_s_vals           # initialize s values 

    jal build_grid_template         # build grid template in memory 
    
    jal draw_background             # call the draw background function
    jal draw_border                 # call the draw border function

    jal fill_board_random           # fill the board randomly (for testing purposes, possibly for lose screen as well)

    jal initialize_fool             # initialize player pos and bounds, and draw first fool


game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    jal check_keyboard_input
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
    
    
	# 4. Sleep
      li $v0  32
      lw $a0 SLEEP_TIME
      syscall
      jal fill_board_random    #just to see update time 
    # 5. Go back to Step 1
    j game_loop

  end_program:
    li $v0, 10                      # end the program
    syscall


##############################################################################
# Display Functions
##############################################################################


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
  # temporaries: t0 = address, t1 = color, t2 = sheen color, t3= background color, t4 = written color, 
  # t7 = bubble pattern t8 = horizontal stop condition, t9 = vertical stop condition
  
  move $t0 $a0
  move $t1 $a1
  lw $t2 COLOR_SHEEN
  lw $t3 BACKGROUND_COLOR
  lw $t4 BACKGROUND_COLOR
  addi $t8 $t0 32
  addi $t9 $t0 4096

  draw_bubble_loop:
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
      move $t4 $t1
      j draw_bubble_write
    set_bubble_color_background:
      move $t4 $t3
      j draw_bubble_write
    set_bubble_color_sheen:
      move $t4 $t2
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





fill_board_random:
    # fills the board with 7 x 14 randomly colored bubbles
    # helper functions: calls get_random_color and draw_bubble, which collectively use t0-4 and t7-9
    # temporaries: t5 = Grid template index t6 = grid template end value

    addi $sp, $sp, -4          # moves stack pointer a word
    sw $ra 0($sp)              # push a word onto the stack

    la $s0 GRID_TEMPLATE       # ensure s0 has correct persistent data, GRID_TEMPLATE address
    addi $t5 $s0 0             # set $t5 to #s0
    addi $t6 $t5 392           # set t6 to loop end condition

  
    random_fill_loop:
        jal get_random_color   # call get_random_color
        move $a1 $v0           # set a1 to random color value stored by v0
        lw $a0 0($t5)          # store values of GRID_TEMPLATE in a0 (parameter for draw_bubble)
        jal draw_bubble        # call draw_bubble
        addi $t5 $t5 4         # increment t5 by 4
        beq $t5 $t6 random_fill_loop_end          # check if loop is over
        j random_fill_loop     # restart loop

    random_fill_loop_end:
        lw $ra, 0($sp)           # load old ra to new $ra from stack
        addi $sp, $sp, 4         # moves the stack pointer up 4
        jr $ra                   # return 


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
    addi $s3 $t0 0                    # set s3 to player bount left 
    addi $s2 $s2 96                   # center s2
    addi $t0 $t0 96                   # center t0 
    addi $s2 $t0 0                    # set player pos 
    addi $t0 $t0 96                   # center t0 
    addi $s4 $t0 0                    # set player bound right 

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
  # input: s2 should store a valid player position
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
  beq $t7 $s2 fool_left_hand_up    # check if a1 is equal to 0
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



##############################################################################
# Helper Functions
##############################################################################


initialize_s_vals:
  # function to initialize s values
  # Only initializes the simple ones, others have their own methods
  # s0 = GRID_TEMPLATE (externally handled)
  # s1 = CURRENT_GRID (externally handled)
  # s2 = CHARACTER_POS (externally handled)
  # s3 = CHARACTER_BOUND_LEFT (externally handled)
  # s4 = CHARACTER_BOUND_RIGHT (externally handled)
  # s5 = IS_PAUSED 

  li $s5 0
  


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
    # function to build the grid template (see .data for details)
    # temporaries: $t0 = address to be stored, $t1 = horizontal loop condition, $t2 = vertical loop condition, t3 = GRID_TEMPLATE
    # $t8 = grid horizontal offset, t9 = column width

    lw $t0 ADDR_DSPL                  # store ADDR_DSPL in t0
    lw $t8 GRID_HORIZONTAL_OFFSET     # store GRID_HORIZONTAL_OFFSET in t8
    lw $t9 COLUMN_WIDTH               # store COLUMN_WIDTH in t9
    add $t0 $t0 $t8                   # add offset and column width to initial address to obtain start of grid template
    add $t0 $t0 $t9                   
    addi $t1 $t0 224                  # set t1 to initial horizontal loop condition
    addi $t2 $t0 53744                 # set t2 to vertical loop condition
    la $t3 GRID_TEMPLATE              # set t3 to GRID_TEMPLATE address

    grid_builder_loop:
      sw $t0 0($t3)                   # store t0 in GRID_TEMPLATE through t3
      addi $t0 $t0 32                  # increment t0 by 32
      addi $t3 $t3 4                  # increment t3 by 4
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



##############################################################################
# Input Functions
##############################################################################

check_keyboard_input:
  # function for checking if a key has been pressed and which one
  # temporaries: t0 = keyboard address, t1 = first word, t2 = second word
  # t3 = q, t4 = p, t5 = w, t6 = s, t7 = a, t8 = d
  
	li 		$v0, 32                 # perfrom syscall 
	li 		$a0, 1
	syscall

    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t1, 0($t0)                  # Load first word from keyboard
    beq $t1 1, keyboard_input      # If first word 1, key is pressed

    end_check_keyboard_input:
    jr $ra 

    keyboard_input:
      lw $a0, 4($t0)                  # Load second word from keyboard
      beq $a0, 0x70, p_pressed        # Check if the key q was pressed
      beq $a0, 0x71, q_pressed        # Check if the key q was pressed
      beq $a0, 0x61, a_pressed        # check if key a was pressed 
      beq $a0, 0x64, d_pressed        # check if key d was pressed 
      # ... check other keys 

      j end_check_keyboard_input      # end

    p_pressed:
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
      # temporaries: t0 = s2 - 32, = player pos - 32
      addi $t0 $s2 -32              # set t0 to playerpos - 32
      bge $t0 $s3 move_fool_left    # check if moving left takes the fool beyond the border
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
      # temporaries: t0 = s2 + 32, = player pos + 32
      addi $t0 $s2 32               # set t0 to playerpos + 32
      ble $t0 $s4 move_fool_right   # check if moving left takes the fool beyond the border
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
        


##############################################################################
# ...
##############################################################################

  

