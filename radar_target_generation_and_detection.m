clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%
d_res = 1;
c = 3e8;
Rmax = 200;
%speed of light = 3e8
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
state = [100, 35]; %position, velocity
target_dist = 100;
target_vel = 35;

%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.

B = c/(2*d_res);
Tchirp = (5.5 * 2 * Rmax)/c;
slope = B/Tchirp;

%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq
                                                       
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)         
    
    curr_time = t(i);
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    
    r_t(i) = target_dist + target_vel * curr_time;      %distance of the target at time instance i from ego
    td(i) = 2*(r_t(i)) / c;     %time delay to target at time instance i
    curr_delay = td(i); %tau
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    
    delay_t = curr_time - curr_delay;
    Tx(i) = cos(2*pi*(fc*curr_time + (slope*curr_time^2)/2.0));
    Rx(i)  = cos(2*pi*(fc*delay_t + (slope*delay_t^2)/2.0));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i) .* Rx(i);
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.

beat_signal = reshape(Mix, Nr, Nd);

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.

fft_beat = fft(beat_signal, Nr);
fft_beat = fft_beat/Nr;

 % *%TODO* :
% Take the absolute value of FFT output

fft_beat = abs(fft_beat);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.

fft_beat = fft_beat(1:Nr/2);

%plotting the range
figure ('Name','Range from First FFT')
subplot(2,1,1)

 % *%TODO* :
 % plot FFT output 

plot(fft_beat); 
axis ([0 200 0 1]);
title('First FFT')


%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.

Tr = 10;
Tc = 4;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation

Gr = 8;
Gc = 4;

% *%TODO* :
% offset the threshold by SNR value in dB

offset = 5;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_level = zeros(1,1);


% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.

thresh_cfar = zeros(size(RDM))-1;
signal_cfar = zeros(size(RDM));

size = size(RDM);
rdm_rows = size(1);
rdm_cols = size(2);

   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR
for row = (Tr + Gr + 1) : (rdm_rows-(Tr+Gr))
    for col = (Tc + Gc + 1) : (rdm_cols - (Tc+Gc))
        window_noise_sum = sum(db2pow(RDM(row-Tr-Gr : row+Tr+Gr, col-Tc-Gc : col+Tc+Gc)), 'all');
        guard_noise_sum = sum(db2pow(RDM(row-Gr : row+Gr, col-Gc : col+Gc)), 'all');
        
        training_noise = window_noise_sum - guard_noise_sum;
        
        
        num_cells_window = (2*(Tr+Gr)+1)*(2*(Tc+Gc)+1);
        num_cells_guard = (2*Gr+1)*(2*Gc+1);
        num_train_cells = num_cells_window - num_cells_guard;
        
        threshold = pow2db(training_noise/num_train_cells);
        threshold = threshold + offset;
        
        thresh_cfar(row,col) = threshold;
        
        CUT = RDM(row,col);
        %disp(['CUT = ' ,num2str(CUT) ,' thresh = ' ,num2str(threshold)]);
        if (CUT > threshold)
            signal_cfar(row,col) = 1;
        else
            %signal_cfar(row,col) = 0;
        end
    end
    
end




% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 
 
%signal_cfar already initialised with zeros.







% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure,surf(doppler_axis,range_axis,signal_cfar);
colorbar;
title('2D CFAR')


 
 