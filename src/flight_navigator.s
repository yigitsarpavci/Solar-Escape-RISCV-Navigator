# ==============================================================================
# Solar Escape: RISC-V Westward Flight Navigator
# ==============================================================================
# Course:       CMPE 344 - Computer Organization (Boğaziçi University)
# Author:       Yiğit Sarp Avcı
# Architecture: RISC-V RV32I (Base Integer Instruction Set)
# Target:       Spike RISC-V ISA Simulator with HTIF
# Memory Map:   ROM @ 0x80000000 (.text, .rodata), RAM @ 0x80010000 (.data, .bss)
#
# Scenario:
#   A catastrophic solar radiation event irradiates the daytime side of Earth.
#   Piloting a cargo aircraft departing from Brussels (index 5), the objective
#   is to perpetually outrun the dawn by navigating westward (SW=2, NW=3).
#   The simulation greedily selects the closest reachable westward airport,
#   manages fuel constraints (capacity 20,000 units, consumption 2 units/km),
#   depletes local airport reserves, records flight telemetry into .bss,
#   and halts when no reachable westward runway remains.
# ==============================================================================

.global _start

.equ NUM_AIRPORTS, 10               # Total number of airports
.equ FUEL_CAPACITY, 20000           # Maximum fuel capacity of the airplane
.equ FUEL_CONSUMPTION_RATE, 2       # Fuel consumption rate of the plane (units/km)

.section .rodata
# Distance matrix [NUM_AIRPORTS x NUM_AIRPORTS]
distances:
    .word  0,     2962,  5357,  7979,  8979,  9591,  8823,  10830,  8754,  6136    # 0: Tokyo
    .word  2962,  0,     2564,  5920,  8006,  9631,  9710,  12970, 11664,  8947    # 1: Hong Kong
    .word  5357,  2564,  0,     5845,   8678, 10881, 11552, 15339, 14101, 10789    # 2: Singapore
    .word  7979,  5920,  5845,  0,     3028,  5497,  6919,  11001, 13400, 13712    # 3: Dubai
    .word  8979,  8006,  8678,  3028,  0,     2488,  4114,  8027,  11002, 13021    # 4: Istanbul
    .word  9591,  9631,  10881, 5497,  2488,  0,     1895,  5540,  8760,  11628    # 5: Brussels
    .word  8823,  9710,  11552, 6919,  4114,  1895,  0,     4163,  6926,  9777     # 6: Reykjavik
    .word 10830, 12970,  15339, 11001,  8027, 5540,  4163,  0,     3974,  8007     # 7: New York
    .word  8754, 11664,  14101, 13400, 11002,  8760, 6926,  3974,  0,     4108     # 8: Los Angeles
    .word  6136,  8947,  10789, 13712, 13021, 11628, 9777,  8007,  4108,  0        # 9: Honolulu

# Direction matrix [NUM_AIRPORTS x NUM_AIRPORTS]
directions:
    .byte -1,  2,  2,  3,  3,  3,  3,  1,  1,  1    # 0: Tokyo
    .byte  1, -1,  2,  3,  3,  3,  3,  1,  1,  1    # 1: Hong Kong
    .byte  1,  1, -1,  3,  3,  3,  3,  3,  1,  1    # 2: Singapore
    .byte  0,  0,  0, -1,  3,  3,  3,  3,  3,  1    # 3: Dubai
    .byte  0,  0,  0,  0, -1,  3,  3,  3,  3,  1    # 4: Istanbul
    .byte  0,  0,  0,  0,  0, -1,  3,  3,  3,  3    # 5: Brussels
    .byte  0,  0,  0,  0,  0,  0, -1,  2,  3,  3    # 6: Reykjavik
    .byte  2,  2,  0,  0,  0,  0,  1, -1,  3,  3    # 7: New York
    .byte  2,  2,  2,  0,  0,  0,  0,  0, -1,  2    # 8: Los Angeles
    .byte  2,  2,  2,  2,  2,  0,  0,  0,  1, -1    # 9: Honolulu

.section .data
current_fuel: .word 20000
airport_supply: .word 17000, 18000, 16000, 17000, 27500, 36500, 15500, 26000, 27000, 40000
current_airport: .word 5            # Starting at Brussels
flight_state: .word 1               # 1 = journey ongoing, -1 = journey ended

.section .bss
distance_traveled: .space 4         # Total distance traveled
flight_history: .space 64           # Keep history of flight with airport indices (store as bytes)

.section .text
    j _start
   
flight_navigation:
    # a0: index of the current airport
    # a1: address of the distances array
    # a2: address of the directions array
    # a3: current fuel level of the plane
    
    li t0, -1           # closest_apt = -1
    li t1, 9999999      # min_dist = infinity
    li t2, 0            # i = 0
    li t3, NUM_AIRPORTS # 10
    li t4, FUEL_CONSUMPTION_RATE # 2

fn_loop:
    bge t2, t3, fn_end  # if i >= 10, break

    # offset = cur_apt * 10 + i
    li t5, 10
    mul t5, a0, t5      # t5 = cur_apt * 10
    add t5, t5, t2      # t5 = cur_apt * 10 + i
    
    # load direction
    add t6, a2, t5      # address of directions[cur_apt][i]
    lb t6, 0(t6)        # t6 = direction

    # check if westward (2 or 3)
    li t5, 2
    beq t6, t5, fn_westward
    li t5, 3
    beq t6, t5, fn_westward
    j fn_continue       # not westward

fn_westward:
    # offset_words = (cur_apt * 10 + i) * 4
    li t5, 10
    mul t5, a0, t5
    add t5, t5, t2
    slli t5, t5, 2      # multiply by 4 for word size

    # load distance
    add t6, a1, t5      # address of distances[cur_apt][i]
    lw t6, 0(t6)        # t6 = distance

    # required fuel = distance * 2
    mul t5, t6, t4      # t5 = required fuel

    # check if required_fuel <= current fuel (a3)
    bgt t5, a3, fn_continue
    
    # check if distance < min_dist (t1)
    bge t6, t1, fn_continue
    
    # update min_dist and closest_apt
    mv t1, t6           # min_dist = distance
    mv t0, t2           # closest_apt = i

fn_continue:
    addi t2, t2, 1
    j fn_loop

fn_end:
    mv a0, t0           # return closest_apt
    ret


refuel:
    # a0: airport index
    # a1: address of the airport fuel array
    # a2: current fuel level of the plane
    
    li t0, FUEL_CAPACITY # 20000
    sub t1, t0, a2      # t1 = needed fuel = 20000 - current_fuel
    
    blez t1, refuel_end # if already full, do nothing

    slli t2, a0, 2      # t2 = airport_index * 4
    add t3, a1, t2      # t3 = address of airport_supply[airport_index]
    lw t4, 0(t3)        # t4 = available fuel

    bge t4, t1, refuel_take_needed
    mv t5, t4           # taken = available
    j refuel_update

refuel_take_needed:
    mv t5, t1           # taken = needed

refuel_update:
    add a2, a2, t5      # current_fuel += taken
    sub t4, t4, t5      # airport_supply -= taken
    sw t4, 0(t3)        # save new supply back

refuel_end:
    mv a0, a2           # return new fuel level
    ret

execute_flight:
    # a0: next airport index
    # a1: address of current_airport
    # a2: address of current_fuel
    # a3: address of distance_traveled
    # a4: address of distances array
    
    lw t0, 0(a1)        # t0 = current_airport

    # get distance
    li t1, 10
    mul t1, t0, t1      # cur_apt * 10
    add t1, t1, a0      # + next_apt
    slli t1, t1, 2      # * 4
    add t2, a4, t1      # addr
    lw t3, 0(t2)        # t3 = distance

    # update distance_traveled
    lw t4, 0(a3)
    add t4, t4, t3
    sw t4, 0(a3)

    # update current_fuel
    lw t5, 0(a2)
    li t6, FUEL_CONSUMPTION_RATE # 2
    mul t6, t3, t6      # consumed fuel
    sub t5, t5, t6
    sw t5, 0(a2)

    # update current_airport
    sw a0, 0(a1)
    ret

check_flight_state:
    # a0: next airport index
    # a1: address of flight_state
    li t0, -1
    bne a0, t0, cfs_continue
    sw t0, 0(a1)        # update flight_state to -1
cfs_continue:
    ret


_start:
    la s0, current_airport
    la s1, current_fuel
    la s2, airport_supply
    la s3, distances
    la s4, directions
    la s5, flight_state
    la s6, distance_traveled
    la s7, flight_history
    li s8, 0            # history index

main_loop:
    # Check flight state
    lw t0, 0(s5)
    li t1, -1
    beq t0, t1, end_simulation

    # Refuel at current airport
    lw a0, 0(s0)
    mv a1, s2
    lw a2, 0(s1)
    jal refuel
    sw a0, 0(s1)        # update current_fuel

    # Flight navigation
    lw a0, 0(s0)
    mv a1, s3
    mv a2, s4
    lw a3, 0(s1)
    jal flight_navigation
    mv s9, a0           # next airport index

    # Check flight state
    mv a0, s9
    mv a1, s5
    jal check_flight_state

    # Check if journey ended after evaluation
    lw t0, 0(s5)
    li t1, -1
    beq t0, t1, end_simulation

    # Execute flight
    mv a0, s9
    mv a1, s0
    mv a2, s1
    mv a3, s6
    mv a4, s3
    jal execute_flight

    # Record to history
    lw t0, 0(s0)
    add t1, s7, s8
    sb t0, 0(t1)
    addi s8, s8, 1

    j main_loop

end_simulation:
    # Exit
    li a7, 10
    ecall
