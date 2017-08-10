breed [susceptible_group susceptible]
breed [infected_group infected]
breed [removed_group removed]

turtles-own [will_vaccinate ; This is a true/false value determining if they will or will not vaccinate thier offspring
            vaccinated      ; This shows whether the agent was vaccinated when they were born
            time_infected   ; The number of days the agent has been infected and contagious
            age             ; The current age in years of this agent
            contacts
            agents_infected]       ; The number of turtles this agent has come into contact with in the last day.

globals [seed opinion_change average_infections]

to setup
  clear-all
  set seed new-seed
  random-seed seed
  set opinion_change 0
  set average_infections [0 0]
  ask patches [set pcolor black]
  let num_vaccinated round (initial_vaccinated * initial_population * .01)
  let num_will_vaccinate round (initial_will_vaccinate * initial_population * .01)

  ;Create all agents so that they are initially in the suseptible group
  create-susceptible_group initial_population [
    setxy random-xcor random-ycor
    set color white
    set vaccinated false
    set will_vaccinate false
    set age 0
    set contacts 0
    if (num_vaccinated > 0) [set vaccinated true set-removed set num_vaccinated (num_vaccinated - 1)] ; If we still need to create the initial infected group add this agent to infected
    if (num_will_vaccinate > 0) [set will_vaccinate true set num_will_vaccinate (num_will_vaccinate - 1)] ; If we still need to create agents who will vaccinate their children do so
  ]
  ask n-of initial_infected susceptible_group [set-infected]
  setup-ages
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Create an even or near even distribution of ages among the agents so that we have an evenly aged population
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-ages
  let curr_age 1
  repeat (death_age - 1)
  [
    ifelse (count turtles with [age = 0]  >= count turtles / (death_age - 1))
    [ask n-of (count turtles / (death_age - 1))  turtles with [age = 0] [set age curr_age]]
    [ask turtles with [age = 0] [set age curr_age]]
    set curr_age curr_age + 1
  ]
end


to go
  ask turtles [set contacts 0] ; Reset number of contacts
  let number_births death ; Kill all turtles who are past the death age and return the number that has been killed
  create-children number_births ; Create the same number of turtles that have been killed
  if (ticks mod sample_rate = 0) [compare-strategy] ; Compare and possibly change strategies
  infect ; Move and infect agents
  immunize ; Check for any turtles who have past the infection period.
  ask turtles [if (ticks mod ticks_per_year = 0) [set age age + 1]]
  tick
  ;if (count infected_group = 0) [stop]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kill all turtles who are over the age specified by the user. This will happend every tick and will remove
; every agent passed the age threshold regardless of other factors. This also returns the number of turtles
; killed so that the population can be kept constant
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report death
  let death_count 0
  ask turtles with [age = death_age]
  [
    set death_count death_count + 1
    die
  ]
  report death_count
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Create new turtles to replace the ones previously killed by old age. This will create new turtles and either
; add them to the susceptible group or add them to the removed group depending on their parents preference for
; vaccination
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to create-children [number_births]
  ask n-of number_births turtles
  [

    hatch-susceptible_group 1
    [
      setxy random-xcor random-ycor
      set color white
      set vaccinated ([will_vaccinate] of myself)
      set will_vaccinate ([will_vaccinate] of myself)
      set age 0
      if (vaccinated = true) [set-removed]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This compares the agents strategy to that of the ones around it and if the compared strategy reslults in
; a "higher" payoff then the agent doing the comparison will change its decision/strategy
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to compare-strategy
  let original_count count turtles with [will_vaccinate = true]
  let vaccine_strategy (-1 * vaccine_morbidity)
  let antivax_startegy (-1 * (infection_morbidity * behavior_sensitivity * ((count infected_group) / (count turtles))))
  ask turtles [
    let my_strategy will_vaccinate
    if ([will_vaccinate] of one-of turtles != my_strategy) [
      if-else (vaccine_strategy > antivax_startegy)
      [set will_vaccinate true]
      [set will_vaccinate false]
    ]
  ]
  set opinion_change (opinion_change + abs (original_count - (count turtles with [will_vaccinate = true])))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Agents will each walk in a particular direction chosen at randomly. The agents that count the number of
; other agents on the same patch and add it to the number of contacts they've had. Finally the agents who
; are infected will attempt to effect each agent around them based on the chance of infectionc chosen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to infect
  repeat steps_per_time [
    ask turtles [
      rt random 180
      forward 1
      set contacts contacts + count turtles-here
      if breed = infected_group [
        ask other turtles-here with [breed = susceptible_group] [if infection_chance_per_contact > random-float 1 [set-infected ask myself [set agents_infected agents_infected + 1]]]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; If the agent has been infected/contagious for the total amount of time they should have they are now immune.
; Add them to the removed group
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to immunize
  ask turtles with [breed = infected_group] [
    set time_infected (time_infected + 1)
    if (time_infected >= ticks_contagious) [set-removed]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; These are helper functions used to set the different breeds and the related attributes of every agent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-infected
  set breed infected_group
  set time_infected 0
  set color red
end

to set-susceptible
  set breed susceptible_group
  set color white
end

to set-removed
  if breed = infected_group
  [
    set average_infections replace-item 0 average_infections (item 0 average_infections + agents_infected)
    set average_infections replace-item 1 average_infections (item 1 average_infections + 1)
  ]
  set breed removed_group
  set color green
end

to-report get-average-infections
  ifelse item 1 average_infections != 0
  [report (item 0 average_infections / item 1 average_infections)]
  [report 0]
end
@#$#@#$#@
GRAPHICS-WINDOW
-7
10
514
532
-1
-1
5.08
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

SLIDER
514
149
723
182
ticks_contagious
ticks_contagious
1
20
14.0
1
1
NIL
HORIZONTAL

SLIDER
514
183
723
216
death_age
death_age
1
100
64.0
1
1
years
HORIZONTAL

SLIDER
515
253
724
286
vaccine_morbidity
vaccine_morbidity
0
1
0.548
.001
1
NIL
HORIZONTAL

SLIDER
515
288
724
321
infection_morbidity
infection_morbidity
0
1
0.734
.001
1
NIL
HORIZONTAL

SLIDER
516
323
724
356
behavior_sensitivity
behavior_sensitivity
0
1
0.784
.001
1
NIL
HORIZONTAL

SLIDER
513
12
723
45
initial_population
initial_population
2
10000
5000.0
1
1
agents
HORIZONTAL

SLIDER
514
115
723
148
initial_will_vaccinate
initial_will_vaccinate
0
100
65.0
1
1
%
HORIZONTAL

BUTTON
727
12
935
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
728
46
935
79
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
729
82
935
127
NIL
ticks
17
1
11

MONITOR
730
129
935
174
NIL
count turtles
17
1
11

SLIDER
514
47
723
80
initial_infected
initial_infected
0
100
1.0
1
1
agents
HORIZONTAL

SLIDER
517
357
724
390
sample_rate
sample_rate
1
100
1.0
1
1
ticks
HORIZONTAL

PLOT
940
12
1310
395
population types
Ticks
Turtles
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"susceptible" 1.0 0 -16777216 true "" "plot count susceptible_group"
"infected" 1.0 0 -2674135 true "" "plot count infected_group"
"removed" 1.0 0 -13840069 true "" "plot count removed_group"

PLOT
1314
12
1718
395
Vaccinated
ticks
turtles
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"vaccinated" 1.0 0 -13840069 true "" "plot count turtles with [vaccinated = true]"
"un-vaccinated" 1.0 0 -2674135 true "" "plot count turtles with [vaccinated = false]"

SLIDER
517
391
724
424
steps_per_time
steps_per_time
0
100
8.0
1
1
NIL
HORIZONTAL

SLIDER
517
426
725
459
infection_chance_per_contact
infection_chance_per_contact
0
1
0.1
.001
1
NIL
HORIZONTAL

SLIDER
515
218
723
251
ticks_per_year
ticks_per_year
01
1000
365.0
1
1
ticks
HORIZONTAL

MONITOR
731
177
935
222
Contacts per day
mean [contacts] of turtles
17
1
11

PLOT
940
399
1311
775
Average Number of Infections per Infected
Ticks
Agetns Infected
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Average" 1.0 0 -13345367 true "" "plot get-average-infections"

PLOT
1315
398
1718
776
Will Vaccinate Children
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"will Vaccinate" 1.0 0 -13840069 true "" "plot count turtles with [will_vaccinate = true]"
"won't vaccinate" 1.0 0 -2674135 true "" "plot count turtles with [will_vaccinate = false]"

SLIDER
514
81
723
114
initial_vaccinated
initial_vaccinated
0
100
10.0
1
1
%
HORIZONTAL

MONITOR
732
224
935
269
Average Infections Created
get-average-infections
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
