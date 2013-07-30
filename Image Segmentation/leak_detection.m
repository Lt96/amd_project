function [ BWleak ] = leak_detection( varargin )
%BWleak = leak_detection(I, [Diskmin Diskmax])
%Takes in grayscaled FA image as input I and returns binary image BWleak consisting solely of
%the leak being extracted. Uses morphological techniques to eliminate
%vessels, optic disks, and other unwanted objects before segmenting out
%area of leakage.  
%Diskmin and Diskmax are optional variables specifying an approximate pixel
%range for the radius of the optic disk


I = varargin{1};
if nargin == 2;
    Diskmin = min(varargin{2});
    Diskmax = max(varargin{2});
else
    Diskmin = 100;
    Diskmax = 200;
end

%Get rid of vessels
se=strel('disk',round(size(I,1)/100));
Iopen=imopen(I,se);


%Find optic disc, if present
%split findcircles algorithm into 4 iterations to improve speed
step = (Diskmax - Diskmin)/4;
centerStrongest = [];
radiusStrongest = [];
maxMetric = 0;
for i = 1:4
    [centers,radii,metrics] = imfindcircles(Iopen,[Diskmin + step*(i-1), Diskmin + step*i],'sensitivity', .97);
    if isempty(metrics)
        continue
    end
    if  metrics(1) > maxMetric
        maxMetric = metrics(1);
        centerStrongest = centers(1,:);
        radiusStrongest = radii(1);
    end
end


if ~isempty(centerStrongest)
        %mask optic disc 
        leeway = 1;
        r = radiusStrongest*(1+leeway);
        [xgrd, ygrd] = meshgrid(1:size(Iopen,2), 1:size(Iopen,1));   
        x = xgrd - centerStrongest(1);  
        y = ygrd - centerStrongest(2);
        omask = x.^2 + y.^2 >= r^2;  
        Inodsc = Iopen.*uint8(omask);
else
    Inodsc = Iopen;
end
clear Iopen
figure, imshow(Inodsc)

% tophat filter to get rid of background
se1 = strel('line',round(size(I,1)/10),0);
se2 = strel('line',round(size(I,2)/10),90);
Itop=imtophat(Inodsc,se1);
clear Inodsc
Itop=imtophat(Itop,se2);
figure, imshow(Itop)
   

%apply threshold using Otsu's method 
thresh = graythresh(Itop)*255;
BWthresh1 = Itop >= thresh;
Ithresh1 = I .* uint8(BWthresh1);
figure, imshow(Ithresh1)


%apply second threshold to further refine leak mask using original
%image 
thresh = graythresh(Ithresh1(Ithresh1>0))*255;
BWleak = Ithresh1 >= thresh;

%clean up final leak mask
BWleak = imfill(BWleak, 'holes');
BWleak = bwmorph(BWleak,'majority');
BWleak = bwmorph(BWleak, 'clean');

%only keep biggest connected region
CC = bwconncomp(BWleak);
numPixels = cellfun(@numel,CC.PixelIdxList);
[~,idx] = max(numPixels);
BWleak = zeros(size(BWleak));
BWleak(CC.PixelIdxList{idx}) = 1;

%show tinted leak
[Iind,map] = gray2ind(I,256);
Irgb=ind2rgb(Iind,map);
Ihsv = rgb2hsv(Irgb);
hueImage = Ihsv(:,:,1);
hueImage(BWleak>0) = 0.011; %red
Ihsv(:,:,1) = hueImage;
satImage = Ihsv(:,:,2);
satImage(BWleak>0) = .8; %semi transparent
Ihsv(:,:,2) = satImage;
Irgb = hsv2rgb(Ihsv);

figure, imshow(Irgb)

end





