We will build an application to control my Garmin TacX Smart Trainer.

The application has a couple of views.

1. View number one is session planning. It features a natural language interface that calls an LLM to create the workouts that I want. For example, I want to be able to say "60-minute over under with overs just above FTP and unders about 10% under FTP. We are doing three sets of 12 minutes each with five minute rest in between."
That is then translated in some kind of formal language back as correct instructions for the controller part of the application.

2. View two is session execution. Here I want to see a graphical view of the entire workout with the intensity in watts and my heart rate and cadence and power output as it plays out. the TrainerRoad execution view is a good example. But I want this view to take up much less screen space because I'm doing other things on my laptop while I'm doing the workout.

3. Post-Session View asks about how hard the workout was. And the workout is exported to Strava when these questions have been answered.

4. Setup view asks about the basic stats of the user, for example FTP, VT1, VT2 and max heart rate. And also allows the user to set custom heart rate and power bands if they want to.

I may want to create iPhone and Android apps once this works on PC, so keep that in mind.