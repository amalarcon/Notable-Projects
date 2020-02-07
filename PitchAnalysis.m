%@author: Aaron Alarcon
%University of Texas at El Paso
%@version: 1.0
%@since: January 16, 2019
%Dependencies: This matlab program needs the audio toolbox in order to
%process the audio signals
%Description: This code takes a live stream of audio from the microphone and graphs
%pitch points where speech is detected. In addition, this program predicts 
%locations where execting a backchannel response would make sense. The user
%can also manually mark points where they gave a backchannel response to
%see how close the program output was



%setting up variable that detects user input
global userPressedButton;
userPressedButton = 0;

%setting up plot
plot(NaN, NaN);
title('Pitch vs Time');
xlabel('Time(s)');
ylabel('Pitch(Hz)'); 
lineOfLowerThresh = yline(0);

annotator= uicontrol('Style', 'pushbutton', 'String', 'Mark');
annotator.Callback = @(~,~)xline(toc,'g');



%setting up audio reader and voice detector
sampleRate = 8000;
lowMaleThreshold = 50;
highMaleThreshold = 250;
deviceReader = audioDeviceReader(sampleRate);
setup(deviceReader);
VAD = voiceActivityDetector;

%setting up backchannel response file
filenames = ["Backchannel1.wav"; "Backchannel2.wav";"Backchannel4.wav"];
cell = loadSounds(filenames);


%pitches holds all the pitches to get the threshold that determines if a 
%pitch is low. The other three variables are used to see if 
pitches = [];
startofLowPitchRegion = 0;
timeOfLastBackchannel = 0;
startOfLastUtterance = 0;


tic
%continuing for 50 seconds
while toc < 50
    if userPressedButton
        hold on ;
        xline(toc, 'g');
        userPressedButton = 0;
    end
    %getting audio signal and timepoint
    audio = deviceReader();
    time = toc;
    
    %getting pitches and locations->converting to seconds
    [frequency, locationInSamples] = pitch(audio, sampleRate,'Range',[lowMaleThreshold,highMaleThreshold]);
    locationInSeconds = locationInSamples/sampleRate;
  
    %setting up variable depicting the time of the last sample
    last = locationInSeconds(end) + time;
    
    %getting probability of voice being present in the frame
    probabilityOfSpeech = VAD(audio);
    
    %We only accept probabilities greater than .99
    if probabilityOfSpeech < .99
        startOfLastUtterance = last;
        startofLowPitchRegion = last;
        continue;
    end
    
    %Since background noise tends to jump between extremely high and low
    %pitches, we remove the pitches that occur too far away from the
    %average pitch of the frame
    avgPitch = mean(frequency);
    marginOfAllowance = 15;
    valid = (avgPitch - marginOfAllowance < frequency)  & (frequency< avgPitch + marginOfAllowance);
    frequency(~valid) = NaN;
    locationsInSeconds(~valid) = NaN;
    
    %if we were left with no elements, we jump to the next iteration
    if sum(valid) == 0
        startOfLastUtterance = last;
        startofLowPitchRegion = last;
        continue;
    end
    
    %Adding new pitches and updating percentile
    pitches = vertcat(pitches, frequency);
    lineOfLowerThresh.Value = prctile(pitches,26);
    
    %plotting results
    hold on
    plot(time + locationInSeconds, frequency, 'b*');
    drawnow
    
    %After our calibration period is over
    if toc > 2
        
        %delete the old timer to free up memory because the backchannel was
        %already produced
        if toc > timeOfLastBackchannel && timeOfLastBackchannel ~= 0
            delete(TriggerDelay)
        end
       
       %looking for if the pitch is considered low
       frequency(frequency < lineOfLowerThresh.Value) = 1;
       frequency(frequency > lineOfLowerThresh.Value) = 0;
       minSpeakingFraction = .75;
       if mean(frequency) > minSpeakingFraction
           
           %Checking if speech has been going on long enough
           if last - startOfLastUtterance < .7
                   continue;
           end 
           
           %if the low pitch length conditions are met
           if last - startofLowPitchRegion >= .11 
                %if a backchannel is valid to produce
                if(last - timeOfLastBackchannel >= .8)
                     %backchannel feedback is triggered .7 seconds after
                     timeOfLastBackchannel = last + .7;
                     TriggerDelay = timer;
                     TriggerDelay.StartDelay = .7;
                     randomNum = randi([1,3], 1, 1);
        
                     TriggerDelay.TimerFcn = {@generateBackchannel, toc, cell{1,randomNum}, cell{2,randomNum}};
                     start(TriggerDelay)
                end 
           end
           else
           %setting new timepoint
           startofLowPitchRegion = last;
            
       end
    end
end
hold off
    
release(deviceReader)



    function buttonPushed(src, event)
        global userPressedButton;
        userPressedButton = 1;
    end
    
    function generateBackchannel(obj, event, time, backchannelPitch, backchannelRate)
        hold on;
        xline(time);
        sound(backchannelPitch, backchannelRate);
    end
    
    function cell = loadSounds(filenames)
        cell = {2,length(filenames)};
        for i =1:length(filenames)
            [cell{1,i}, cell{2,i}] = audioread(filenames(i));
        end
    end
    
    
    


        
        
