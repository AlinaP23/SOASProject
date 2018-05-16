globals [
  hubMarketPrice
  hubMarketSupply
  hubMarketDemand
  hubMarketExcessDemand
  factoryMarketPrice
  weekDay
]

directed-link-breed [activeLinks activeLink]
directed-link-breed [inactiveLinks inactiveLink]

breed [houses house]
breed [shops shop]
breed [hubs hub]
breed [factories factory]

houses-own [
  consumption
  production
  hubId
  budgetList
  priceMemoryList
]

shops-own [
  consumption
  consumptionLevel
  hubId
]

factories-own [
  production
]

hubs-own [
  localSupply
  localDemand
  localPrice
  localSurplus ; what do we use this for?
  localLack
  localCoverage ; added
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  set weekDay 1
  ifelse number-houses < number-shops [
    display
    user-message "The number of houses must be greater than the number of shops."
    stop
  ][
    make-hubs
    make-houses
    make-shops
    make-factories
  ]
end

to make-houses
  create-houses number-houses
  [
    set shape "house"
    set hubId random number-hubs
    set color green
    set priceMemoryList [0 0] ; [beforeNoon afterNoon]
    set production [0 0 0 0 0 0 0.5 1 2 3 4 5 6 5 4 3 2 1 0.5 0 0 0 0 0] ; expecting sunrise around 6am and sunset around 6pm
    set consumption [1 1 1 1 1 1 1 1 1 1 1.5 1.5 1.5 1.5 1.5 1.5 1.5 1 1 1 1 1 1 1]
    set consumption personalizeConsumption consumption
    set budgetList personalizeBudgetList consumption ; [beforeNoon afterNoon]
    show "consumption"
    show consumption
    show "budgetList"
    show budgetList
  ]
  layout-circle sort-by [ [a b] -> [hubId] of a < [hubId] of b ] houses max-pxcor - 1
  ask houses [
    let my-hub hubs with [ who = [hubId] of myself ]
    create-activeLinks-to my-hub
    create-activeLinks-from my-hub
  ]
end

to-report personalizeConsumption [cons]
  ; determine breakfast & dinner peaktimes (normal distribution)
  let breakfastTime random-normal 8 1.5
  if breakfastTime < 0 [set breakfastTime 0]
  let dinnerTime random-normal 20 2
  if dinnerTime < 0 [set dinnerTime 0]
  ; determine length of increased energy consumption periods (normal distribution)
  let breakfastDuration random-normal 1.5 1
  if breakfastDuration < 0 [set breakfastDuration 0]
  let dinnerDuration random-normal 3 2
  if dinnerDuration < 0 [set dinnerDuration 0]
  ; determine height of the peak in KW -> https://jaiminshahblog.wordpress.com/
  let breakfastConsumption random-normal 3 1
  if breakfastConsumption < 0 [set breakfastConsumption 0]
  let dinnerConsumption random-normal 7.5 2
  if dinnerConsumption < 0 [set dinnerConsumption 0]

  ; personalize consumption list
  ; BREAKFAST
  let breakfastBeginning breakfastTime - breakfastDuration / 2
  let breakfastCounter 0
  let timeToSet breakfastBeginning
  repeat floor (breakfastDuration / 2) [
    set timeToSet adjustTo24Hours (breakfastBeginning + breakfastCounter)
    set cons replace-item timeToSet cons (breakfastConsumption / ( breakfastDuration - 1 ) * (breakfastCounter + 1))
    set breakfastCounter breakfastCounter + 1
  ]
  set cons replace-item (breakfastTime - 1) cons breakfastConsumption
  set breakfastCounter 0
  repeat breakfastDuration / 2 [
    set timeToSet adjustTo24Hours (breakfastTime + breakfastCounter)
    set cons replace-item timeToSet cons (breakfastConsumption - (breakfastConsumption / ( breakfastDuration - 1 ) * (breakfastCounter + 1)))
    set breakfastCounter breakfastCounter + 1
  ]
  ; DINNER
  let dinnerBeginning dinnerTime - dinnerDuration / 2
  let dinnerCounter 0
  set timeToSet dinnerBeginning
  repeat floor (dinnerDuration / 2) [
    set timeToSet adjustTo24Hours (dinnerBeginning + dinnerCounter)
    set cons replace-item timeToSet cons (dinnerConsumption / ( dinnerDuration - 1 ) * (dinnerCounter + 1))
    set dinnerCounter dinnerCounter + 1
  ]
  ifelse dinnerTime < 25 [
    set cons replace-item (dinnerTime - 1) cons dinnerConsumption
  ][
    set cons replace-item (dinnerTime - 25) cons dinnerConsumption
  ]
  set dinnerCounter 0
  repeat dinnerDuration / 2 [
    set timeToSet adjustTo24Hours (dinnerTime + dinnerCounter)
    set cons replace-item timeToSet cons (dinnerConsumption - (dinnerConsumption / ( dinnerDuration - 1 ) * (dinnerCounter + 1)))
    set dinnerCounter dinnerCounter + 1
  ]
  report cons
end

to-report adjustTo24Hours [time]
  if time < 0 [set time (24 + time)]
  if time > 23 [set time (time - 24)]
  report time
end

to-report personalizeBudgetList [consumptionList]
  let sumBeforeNoon sum sublist consumptionList 0 12
  let sumAfterNoon sum sublist consumptionList 12 24
  let priceLevel random 3
  let budget [0 0]
  ifelse priceLevel = 0 [
    set sumBeforeNoon (sumBeforeNoon * 1)
    set sumAfterNoon (sumAfterNoon * 1)
  ][  ifelse priceLevel = 1 [
      set sumBeforeNoon (sumBeforeNoon * 1.5)
      set sumAfterNoon (sumAfterNoon * 1.5)
    ][
      set sumBeforeNoon (sumBeforeNoon * 2)
      set sumAfterNoon (sumAfterNoon * 2)
    ]
  ]
  set budget replace-item 0 budget sumBeforeNoon
  set budget replace-item 1 budget sumAfterNoon
  report budget
end

to make-shops
  create-shops number-shops
  [
    set shape "building store"
    set hubId random number-hubs
    set color green
    set consumptionLevel random 3
    ifelse consumptionLevel = 0 [
      set consumption [1 1 1 1 1 1 1 1.2 1.5 1.8 2 2 2 2 2 2 2 2 2 1.8 1.7 1.5 1.1 1]
    ] [ ifelse consumptionLevel = 1 [
        set consumption [1 1 1 1 1 1 1 2 3.5 4.2 5 5 5 5 5 5 5 5 5 4.2 3.8 3.3 2 1]
      ][
        set consumption [1 1 1 1 1 1 1 2.3 4.3 5.9 7 7 7 7 7 7 7 7 7 5.9 4.5 3.5 2.2 1]
      ]
    ]
  ]
  layout-circle sort-by [ [a b] -> [hubId] of a < [hubId] of b ] shops max-pxcor - 5
  ask shops [
    let my-hub hubs with [ who = [hubId] of myself ]
    create-activeLinks-from my-hub
  ]
end

to make-hubs
  create-hubs number-hubs
  [
    set shape "circle"
    set size 0.75
  ]
  layout-circle sort-by [ [a b] -> [who] of a < [who] of b ] hubs max-pxcor - 10
  ask hubs [
    create-activeLinks-to other hubs [
      hide-link
    ]
  ]
end

to make-factories
  create-factories 1
  [
    set shape "factory"
    set color grey
    set size 2
    setxy 0 0
  ]
  ask factories [
    create-activeLinks-to hubs
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; Main Procedure  ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  computeLocalPrices            ; initially: 1€
  computeHubMarketPrice         ; initially: 1.5€
  computeFactoryMarketPrice     ; initially: 2€


  energyDistribution

  tick
  if ticks > 23 [     ; ticks simulate the time/hour -> reset to 0 when end of day (24h) is reached
    reset-ticks
    ifelse weekDay = 7 [
      set weekDay 1
      houseConsumptionAdjustment
    ] [
      set weekDay weekDay + 1
    ]
  ]
end

;------------------------;
;;; Price Computations ;;;
;------------------------;
to computeLocalPrices
  ; calculate price based on demand and supply on the local markets (maybe just focus on difference between the 2 variables?!)
  ask hubs [
    let my-houses houses with [ hubId = [who] of myself ]
    let my-shops shops with [ hubId = [who] of myself ]
    set localDemand sum[ item ticks consumption ] of my-houses + sum[item ticks consumption] of my-shops
    set localSupply sum[ item ticks production] of my-houses
    ifelse localDemand < localSupply [
      set localSurplus localSupply - localDemand
      set localLack 0
      ; set localPrice 1 - (0.5 * ??) --> below 1€ (above 0.5€?)
    ] [
      set localSurplus 0
      set localLack localDemand - localSupply
      ; set localPrice 1 + (0.5 * ??) --> above 1€ (below 1.5€?!)
    ]

  ]
end

to computeHubMarketPrice
  ; calculate price based on demand and supply on the hub market
  set hubMarketSupply sum[localSurplus] of hubs
  set hubMarketDemand sum[localLack] of hubs
  ifelse hubMarketDemand < hubMarketSupply [
   ; set hubMarketPrice 1.5 - (0.5 * ??) --> below 1.5€ (above 1€?!)
  ][
   ; set hubMarketPrice 1.5 + (0.5 * ??) --> above 1.5€ (below 2€?!)
  ]
end

to computeFactoryMarketPrice
  ; calculate price based on (excess) demand of the hubs
  ifelse hubMarketSupply < hubMarketDemand [
    set hubMarketExcessDemand hubMarketDemand - hubMarketSupply
    ; set factoryMarketPrice 2 + (0.5 * ??) --> only 2€ or above?
  ][
    set hubMarketExcessDemand 0
  ]
end

;-------------------------;
;;; Energy Distribution ;;;
;-------------------------;
to energyDistribution
  ask hubs [
    ; distribute 1. local energy, 2. hub energy, 3. factory energy
    ; every house needs to track expenditures on energy per hour!, shops just don't care

    ; 1) Use agent-set: Go through houses and shops with same hub-id as the hubs who-number
    ; and get their energy level
    ; Find and record persentage of coverage.

    let my-houses houses with [ hubId = [who] of myself ]
    let my-shops shops with [ hubId = [who] of myself ]
    set localDemand sum [item ticks consumption] of my-houses + sum [consumption] of my-shops ; correct use of supply and demand?
    set localSupply sum [item ticks production] of my-houses
    set localCoverage localSupply / localDemand     ; >1 if surpluss of energy
  ]

    ; 2) Use agent-set: Go through hubs and check their energy levels.
    ; Find persentage coverage:
    ; if less than 1: charge this persentage of each hubs request for energy with hub-prize, pay each hub for all their provided energy
    ;    then charge the remaining persentage of the hubs requests with factory prize and record factory use.
    ; else: charge all required energy of each hub with hub-prize and pay the persentage - 1 of each hub for their provided energy.

  let totalDemand sum [localDemand] of hubs
  let totalSupply sum [localSupply] of hubs
  let totalCoverage totalSupply / totalDemand

  ; Find current prices for the different tears
  ;let localPrice computeLocalPrices
  let hubPrice 1.5 ;computeHubMarketPrice  <------------------ Temporary!
  let factPrize 2 ;computeFactoryMarketPrice <------------------ Temporary!


  ask hubs [
    ; 3) Use agent-set: Go through houses and shops with same hub-id as the hubs who-number
    ; Charge each house and shop with summed up prize (local*persentageL + hub*persentageH + fact*persentageF) per package
    ; Pay each house for produced energy (local*persentageL + hub*persentageH) per package.

    let my-houses houses with [ hubId = [who] of myself ]
    let my-shops shops with [ hubId = [who] of myself ]

    ;; Calculate combined payment for each house

    let locallyProvidedPart 0
    let locallySoldPart 0
    let hubProvidedPart 0
    let factProvidedPart 0
    let externSoldPart 0


    ifelse localCoverage < 1
    [ ; Energy must be bought from external seller(s)

      set locallySoldPart 1  ; All locally produced energy sold in the local market
      set locallyProvidedPart localCoverage ; What was not covered by locally produced energy had to be bought externally
    ]
    [ ; Surpluss of energy available for sale to external buyer(s)

      set locallyProvidedPart 1 ; All locally consumed energy bought in the local market
      set locallySoldPart localDemand / localSupply
    ]

    ifelse totalCoverage < 1
    [ ; Energy must be bought from factory

      let hubCoverage totalCoverage
      let factCoverage 1 - totalCoverage ; <-------------------------- Maybe record this

      set hubProvidedPart ( 1 - locallyProvidedPart ) * hubCoverage
      set factProvidedPart (1 - locallyProvidedPart ) * factCoverage

      set externSoldPart (1 - locallySoldPart) * ( totalDemand / totalSupply )

    ]
    [ ; Not all energy in system was used

      set hubProvidedPart 1 - locallyProvidedPart ; Full hub coverage
      set factProvidedPart 0

      set externSoldPart ( 1 - locallySoldPart) * ( 2 - totalCoverage )
    ]

    ask my-houses [
      let localPrize 1 ; <------------------ Temporary!
      let energyLevel [item ticks consumption] of myself - [item ticks production] of myself
      let prizeToPay energyLevel * ( localPrize * locallyProvidedPart +  hubProvidedPart * hubPrice + factProvidedPart * factPrize )
      pay prizeToPay
    ]
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;
;;;     Updates     ;;;
;;;;;;;;;;;;;;;;;;;;;;;
to houseConsumptionAdjustment ; at the end of the week, each house adjusts its consumption according to the last week's expenses

end

to pay [prizeToPay]


end

@#$#@#$#@
GRAPHICS-WINDOW
388
10
1147
770
-1
-1
22.76
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
23
31
195
64
number-houses
number-houses
15
100
38.0
1
1
NIL
HORIZONTAL

BUTTON
234
53
301
86
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

SLIDER
23
74
195
107
number-hubs
number-hubs
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
23
117
195
150
number-shops
number-shops
0
100
33.0
1
1
NIL
HORIZONTAL

BUTTON
235
101
298
134
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
29
215
145
260
weekDay
weekDay
17
1
11

MONITOR
27
270
146
315
NIL
hubMarketSupply
17
1
11

MONITOR
28
326
145
371
NIL
hubMarketDemand
17
1
11

PLOT
28
401
332
586
Factory Production
time
price
0.0
24.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot hubMarketExcessDemand"

MONITOR
156
216
331
261
Current Hub Market Price
hubMarketPrice
17
1
11

MONITOR
158
271
331
316
Current Factory Market Price
factoryMarketPrice
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

building store
false
0
Rectangle -7500403 true true 30 45 45 240
Rectangle -16777216 false false 30 45 45 165
Rectangle -7500403 true true 15 165 285 255
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 30 180 105 240
Rectangle -16777216 true false 195 180 270 240
Line -16777216 false 0 165 300 165
Polygon -7500403 true true 0 165 45 135 60 90 240 90 255 135 300 165
Rectangle -7500403 true true 0 0 75 45
Rectangle -16777216 false false 0 0 75 45

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

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

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
NetLogo 6.0.2
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
