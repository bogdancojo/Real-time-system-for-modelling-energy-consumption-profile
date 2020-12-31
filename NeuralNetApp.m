clc
close all

Refrigeration = readtable('DataExport.xlsx','Sheet','Refrigeration','Range','C1:D70079');
Refrigeration.Properties.VariableNames{1} = 'DateTime';
Refrigeration.Properties.VariableNames{2} = 'ConsumptionKWH';
Positives = readtable('DataExport.xlsx','Sheet','Positives','Range','C1:D70081');
Positives.Properties.VariableNames{1} = 'DateTime';
Positives.Properties.VariableNames{2} = 'ConsumptionKWH';
Negatives = readtable('DataExport.xlsx','Sheet','Negatives','Range','C1:D70081');
Negatives.Properties.VariableNames{1} = 'DateTime';
Negatives.Properties.VariableNames{2} = 'ConsumptionKWH';
Humidity = readtable('DataExport.xlsx','Sheet','External Humidity','Range','C1:D69696');
Humidity.Properties.VariableNames{1} = 'DateTime';
Humidity.Properties.VariableNames{2} = 'HumidityProc';
Temperature = readtable('DataExport.xlsx','Sheet','External Temperature','Range','C1:D69696');
Temperature.Properties.VariableNames{1} = 'DateTime';
Temperature.Properties.VariableNames{2} = 'TemperatureC';

Target_DateTime = intersect(intersect(intersect(intersect(Positives.DateTime,Refrigeration.DateTime),Humidity.DateTime),Temperature.DateTime),Negatives.DateTime);
Positives = convertvars(Positives,{'DateTime'},'datetime');
Negatives = convertvars(Negatives,{'DateTime'},'datetime');
Refrigeration = convertvars(Refrigeration,{'DateTime'},'datetime');
Humidity = convertvars(Humidity,{'DateTime'},'datetime');
Temperature = convertvars(Temperature,{'DateTime'},'datetime');


Negatives(~ismember(Negatives.DateTime,Target_DateTime),:) = [];
Refrigeration(~ismember(Refrigeration.DateTime,Target_DateTime),:) = [];
Humidity(~ismember(Humidity.DateTime,Target_DateTime),:) = [];
Temperature(~ismember(Temperature.DateTime,Target_DateTime),:) = [];
Positives(~ismember(Positives.DateTime,Target_DateTime),:) = [];

data_string = string(Target_DateTime);
format longE
NumericDate = datenum(data_string);

TotalConsumption = Positives.ConsumptionKWH + Negatives.ConsumptionKWH + Refrigeration.ConsumptionKWH;
Data = [NumericDate TotalConsumption Humidity.HumidityProc Temperature.TemperatureC];
T = array2table(Data);
T.Properties.VariableNames{1} = 'DateTime';
T.Properties.VariableNames{2} = 'ConsumptionKWH';
T.Properties.VariableNames{3} = 'HumidityProc';
T.Properties.VariableNames{4} = 'TemperatureC';

input = cell(100,1);
n = 100;
k = 672;
j = 1;
trainLength = 99;
testLength = n - trainLength;
num = 23; % numarul saptamanii asupra careia se va realiza predictia
dataTrain = cell(trainLength,1);
dataTest = cell(testLength,1);
count = 0;
for i = 1 : n
   input{i,1} = Data(j:k,:)';
   if (i == num)
       dataTest{1,1} = Data(j:k,:)';
       count = count + 1;
   else
       dataTrain{i - count,1} = Data(j:k,:)';
   end
   k = k + 672;
   j = j + 672;   
end

Xtrain = cell(trainLength,1);
Ytrain = cell(trainLength,1);
inter = cell(trainLength,1);

for i = 1 : trainLength
   inter{i} = dataTrain{i}; 
   inter{i}(2,:) = [];
end

for i = 1 : trainLength
    Xtrain{i} = inter{i};
    Ytrain{i} = dataTrain{i}(2,:);
end

mu = mean([Xtrain{:}],2);
sig = std([Xtrain{:}],0,2);
for i = 1:numel(Xtrain)
    Xtrain{i} = (Xtrain{i} - mu) ./ sig;
end

nrTrasaturi = 3;
nrRaspuns = 1;
nrUnitatiAscunse = 200;

layers = [ ...
    sequenceInputLayer(nrTrasaturi)
    lstmLayer(nrUnitatiAscunse,'OutputMode','sequence')
    fullyConnectedLayer(100)
    dropoutLayer(0.25)
    fullyConnectedLayer(nrRaspuns)
    regressionLayer];

maxEpochs = 70;
miniBatchSize = 30;

options = trainingOptions('adam', ...
    'MaxEpochs',maxEpochs, ...
    'MiniBatchSize',miniBatchSize, ...
    'InitialLearnRate',0.01, ...
    'GradientThreshold',1, ...
    'Shuffle','never', ...
    'Plots','training-progress',...
    'Verbose',0);

net = trainNetwork(Xtrain,Ytrain,layers,options);

Xtest = cell(testLength,1);
inter1 = cell(testLength,1);

for i = 1 : testLength
   inter1{i} = dataTest{i}; 
   inter1{i}(2,:) = [];
end

for i = 1 : testLength
    Xtest{i} = inter1{i};
end

Ytest = cell(testLength,1);

for i = 1 : testLength
     Ytest{i} = dataTest{i}(2,:);
end

for i = 1 : testLength
    Xtest{i} = (Xtest{i} - mu) ./ sig;
end

Ypred = predict(net,Xtest,'MiniBatchSize',1);
rmse = sqrt(mean((Ypred{1} - Ytest{1}).^2))

figure(1)
hold on
plot(Ypred{1})
plot(Ytest{1})
ylabel('Consum(Kwh)')
xlabel('Moment de timp')
hold off

Predsum = 0;
Realsum = 0;
for i = 1 : 672
   Predsum = Predsum + Ypred{1}(:,i); 
   Realsum = Realsum + Ytest{1}(:,i); 
end

totalConsumption = abs(Realsum - Predsum);
