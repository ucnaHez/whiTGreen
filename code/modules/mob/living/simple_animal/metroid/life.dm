
/mob/living/simple_animal/metroid
   var/AIproc = 0 // determines if the AI loop is activated
   var/Atkcool = 0 // attack cooldown
   var/Tempstun = 0 // temporary temperature stuns
   var/Discipline = 0 // if a slime has been hit with a freeze gun, or wrestled/attacked off a human, they become disciplined and don't attack anymore for a while
   var/SStun = 0 // stun variable


/mob/living/simple_animal/metroid/Life()
   set invisibility = 0
   set background = BACKGROUND_ENABLED

   if (notransform)
      return
   if(..())
      handle_nutrition()
      handle_targets()

/mob/living/simple_animal/metroid/proc/AIprocess()  // the master AI process

   if(AIproc || stat == DEAD || client) return

   var/hungry = 0
   if (nutrition < get_starve_nutrition())
      hungry = 2
   else if (nutrition < get_grow_nutrition() && prob(25) || nutrition < get_hunger_nutrition())
      hungry = 1

   AIproc = 1

   while(AIproc && stat != DEAD && (attacked || hungry || rabid || Victim))
      if(Victim) // can't eat AND have this little process at the same time
         break

      if(!Target || client)
         break

      if(Target.health <= -70 || Target.stat == DEAD)
         Target = null
         AIproc = 0
         break

      if(Target)
         for(var/mob/living/simple_animal/metroid/M in view(1,Target))
            if(M.Victim == Target)
               Target = null
               AIproc = 0
               break
         if(!AIproc)
            break

         if(Target in view(1,src))
            if(istype(Target, /mob/living/silicon))
               if(!Atkcool)
                  Atkcool = 1
                  spawn(45)
                     Atkcool = 0

                  if(Target.Adjacent(src))
                     Target.attack_slime(src)
               return
            if(!Target.lying && prob(80))

               if(Target.client && Target.health >= 20)
                  if(!Atkcool)
                     Atkcool = 1
                     spawn(45)
                        Atkcool = 0

                     if(Target.Adjacent(src))
                        Target.attack_slime(src)

               else
                  if(!Atkcool && Target.Adjacent(src))
                     Feedon(Target)

            else
               if(!Atkcool && Target.Adjacent(src))
                  Feedon(Target)

         else
            if(Target in view(7, src))
               if(!Target.Adjacent(src)) // Bug of the month candidate: slimes were attempting to move to target only if it was directly next to them, which caused them to target things, but not approach them
                  step_to(src, Target)

            else
               Target = null
               AIproc = 0
               break

      var/sleeptime = movement_delay()
      if(sleeptime <= 0) sleeptime = 1

      sleep(sleeptime + 2) // this is about as fast as a player slime can go

   AIproc = 0

/mob/living/simple_animal/metroid/handle_environment(datum/gas_mixture/environment)
   if(!environment)
      return

   //var/environment_heat_capacity = environment.heat_capacity()
   var/loc_temp = get_temperature(environment)

   if(loc_temp < 310.15) // a cold place
      bodytemperature += adjust_body_temperature(bodytemperature, loc_temp, 1)
   else // a hot place
      bodytemperature += adjust_body_temperature(bodytemperature, loc_temp, 1)

   //Account for massive pressure differences

   if(bodytemperature < (T0C + 5)) // start calculating temperature damage etc
      if(bodytemperature <= (T0C - 40)) // stun temperature
         Tempstun = 1

      if(bodytemperature <= (T0C - 50)) // hurt temperature
         if(bodytemperature <= 50) // sqrting negative numbers is bad
            adjustBruteLoss(200)
         else
            adjustBruteLoss(round(sqrt(bodytemperature)) * 2)

   else
      Tempstun = 0

   updatehealth()

   return //TODO: DEFERRED

/mob/living/simple_animal/metroid/proc/adjust_body_temperature(current, loc_temp, boost)
   var/temperature = current
   var/difference = abs(current-loc_temp)   //get difference
   var/increments// = difference/10         //find how many increments apart they are
   if(difference > 50)
      increments = difference/5
   else
      increments = difference/10
   var/change = increments*boost   // Get the amount to change by (x per increment)
   var/temp_change
   if(current < loc_temp)
      temperature = min(loc_temp, temperature+change)
   else if(current > loc_temp)
      temperature = max(loc_temp, temperature-change)
   temp_change = (temperature - current)
   return temp_change

/mob/living/simple_animal/metroid/handle_regular_status_updates()

   if(..())
      if(prob(30))
         adjustBruteLoss(-1)

/mob/living/simple_animal/metroid/proc/handle_nutrition()

   if(docile) //God as my witness, I will never go hungry again
      nutrition = 700
      return

   if(prob(15))
      nutrition -= 1 + is_adult

   if(nutrition <= 0)
      nutrition = 0
      if(prob(75))
         adjustBruteLoss(rand(0,5))

   else if (nutrition >= get_grow_nutrition() && amount_grown < 10)
      nutrition -= 20
      amount_grown++

   if(amount_grown >= 10 && !Victim && !Target && !ckey)
      if(is_adult)
         Reproduce()
      else
         Evolve()

/mob/living/simple_animal/metroid/proc/add_nutrition(var/nutrition_to_add = 0, var/lastnut = 0)
   nutrition = min((nutrition + nutrition_to_add), get_max_nutrition())
   if(nutrition >= (lastnut + 50))
      if(prob(80))
         lastnut = nutrition
         powerlevel++
         if(powerlevel > 10)
            powerlevel = 10
            adjustBruteLoss(-10)



/mob/living/simple_animal/metroid/proc/handle_targets()
   if(Tempstun)
      if(!Victim) // not while they're eating!
         canmove = 0
   else
      canmove = 1

   if(attacked > 50) attacked = 50

   if(attacked > 0)
      attacked--

   if(Discipline > 0)

      if(Discipline >= 5 && rabid)
         if(prob(60)) rabid = 0

      if(prob(10))
         Discipline--

   if(!client)
      if(!canmove) return

      if(Victim) return // if it's eating someone already, continue eating!

      if(Target)
         --target_patience
         if (target_patience <= 0 || SStun || Discipline || attacked || docile) // Tired of chasing or something draws out attention
            target_patience = 0
            Target = null

      if(AIproc && SStun) return

      var/hungry = 0 // determines if the slime is hungry

      if (nutrition < get_starve_nutrition())
         hungry = 2
      else if (nutrition < get_grow_nutrition() && prob(25) || nutrition < get_hunger_nutrition())
         hungry = 1

      if(hungry == 2 && !client) // if a slime is starving, it starts losing its friends
         if(Friends.len > 0 && prob(1))
            var/mob/nofriend = pick(Friends)
            --Friends[nofriend]

      if(!Target)
         if(will_hunt() && hungry || attacked || rabid) // Only add to the list if we need to
            var/list/targets = list()

            for(var/mob/living/L in view(7,src))

               if(ismetroid(L) || L.stat == DEAD) // Ignore other slimes and dead mobs
                  continue

               if(L in Friends) // No eating friends!
                  continue

               if(issilicon(L) && (rabid || attacked)) // They can't eat silicons, but they can glomp them in defence
                  targets += L // Possible target found!

               if(istype(L, /mob/living/carbon/human)) //Ignore slime(wo)men
                  var/mob/living/carbon/human/H = L
                  if(H.dna)
                     if(src.type in H.dna.species.ignored_by)
                        continue

               if(!L.canmove) // Only one slime can latch on at a time.
                  var/notarget = 0
                  for(var/mob/living/simple_animal/metroid/M in view(1,L))
                     if(M.Victim == L)
                        notarget = 1
                  if(notarget)
                     continue

               targets += L // Possible target found!

            if(targets.len > 0)
               if(attacked || rabid || hungry == 2)
                  Target = targets[1] // I am attacked and am fighting back or so hungry I don't even care
               else
                  for(var/mob/living/carbon/C in targets)
                     if(!Discipline && prob(5))
                        if(ishuman(C) || isalienadult(C))
                           Target = C
                           break

                     if(islarva(C) || ismonkey(C))
                        Target = C
                        break

         if (Target)
            target_patience = rand(5,7)
            if (is_adult)
               target_patience += 3

         else if(hungry)
            if (holding_still)
               holding_still = max(holding_still - hungry, 0)
            else if(canmove && isturf(loc) && prob(50))
               step(src, pick(cardinal))

         else
            if(holding_still)
               holding_still = max(holding_still - 1, 0)
            else if (docile && pulledby)
               holding_still = 10
            else if(canmove && isturf(loc) && prob(33))
               step(src, pick(cardinal))
      else if(!AIproc)
         spawn()
            AIprocess()

/mob/living/simple_animal/metroid/handle_automated_movement()
   return //slime random movement is currently handled in handle_targets()

/mob/living/simple_animal/metroid/handle_automated_speech()
   return //slime random speech is currently handled in handle_speech()

/mob/living/simple_animal/metroid/proc/handle_speech()
   if(prob(1))
      emote(pick("bounce","sway","light","vibrate","jiggle"))
   else
      var/t = 10
      var/slimes_near = 0
      var/dead_slimes = 0
      var/friends_near = list()
      for (var/mob/living/L in view(7,src))
         if(ismetroid(L) && L != src)
            ++slimes_near
            if (L.stat == DEAD)
               ++dead_slimes
         if (L in Friends)
            t += 20
            friends_near += L
      if (nutrition < get_hunger_nutrition()) t += 10
      if (nutrition < get_starve_nutrition()) t += 10
      if (prob(2) && prob(t))
         var/phrases = list()
         if (Target) phrases += "[Target]... looks tasty..."
         if (nutrition < get_starve_nutrition())
            phrases += "So... hungry..."
            phrases += "Very... hungry..."
            phrases += "Need... food..."
            phrases += "Must... eat..."
         else if (nutrition < get_hunger_nutrition())
            phrases += "Hungry..."
            phrases += "Where is the food?"
            phrases += "I want to eat..."
         if (rabid || attacked)
            phrases += "Hrr..."
            phrases += "Unn..."
         if (attacked)
            phrases += "Grrr..."
         if (bodytemperature < T0C)
            phrases += "Cold..."
         if (bodytemperature < T0C - 30)
            phrases += "So... cold..."
            phrases += "Very... cold..."
         if (bodytemperature < T0C - 50)
            phrases += "..."
            phrases += "C... c..."
         if (powerlevel > 3) phrases += "Bzzz..."
         if (powerlevel > 5) phrases += "Zap..."
         if (powerlevel > 8) phrases += "Zap... Bzz..."
         if (slimes_near) phrases += "Brother..."
         if (slimes_near > 1) phrases += "Brothers..."
         if (dead_slimes) phrases += "What happened?"
         if (!slimes_near)
            phrases += "Lonely..."
         for (var/M in friends_near)
            phrases += "[M]... friend..."
            if (nutrition < get_hunger_nutrition())
               phrases += "[M]... feed me..."
         say (pick(phrases))

/mob/living/simple_animal/metroid/proc/get_max_nutrition() // Can't go above it
   if (is_adult) return 1200
   else return 1000

/mob/living/simple_animal/metroid/proc/get_grow_nutrition() // Above it we grow, below it we can eat
   if (is_adult) return 1000
   else return 800

/mob/living/simple_animal/metroid/proc/get_hunger_nutrition() // Below it we will always eat
   if (is_adult) return 600
   else return 500

/mob/living/simple_animal/metroid/proc/get_starve_nutrition() // Below it we will eat before everything else
   if(is_adult) return 400
   else return 300

/mob/living/simple_animal/metroid/proc/will_hunt(var/hunger = -1) // Check for being stopped from feeding and chasing
   if (docile)   return 0
   if (hunger == 2 || rabid || attacked) return 1
   if (holding_still) return 0
   return 1
