function [ final_hypo, final_hyper, final_abnormal, scores ] = find_amd( pid, eye, time, varargin )
%Returns binary image indicating location of hypofluorescence
status = 'generate'; 
if length(varargin) == 1
    debug = varargin{1};
elseif isempty(varargin)
    debug = 1;
elseif length(varargin) == 2
    debug = varargin{1};
    status = varargin{2};
else
    throw(MException('MATLAB:paramAmbiguous','Incorrect number of input arguments'));
end

t = cputime;
std_size = 768;

%Add the path for the useful directories
addpath('..');
addpath(genpath('../Test Set'));
addpath('../intensity normalization');
addpath('../snake');
addpath(genpath('../libsvm-3.18'))
addpath(genpath('../liblinear-1.94'))
addpath('../Skeleton');
addpath('../Vessel Detection - Chris');
addpath('../OD Detection - Chris');
addpath('../Fovea Detection - Chris');
addpath('../Graph Cuts');
addpath('../superpixels');

%initialize output
scores = struct;
scores.hypo_area = 0;
scores.hypo_intensity = 0;
scores.hypo_score = 0;
scores.hyper_area = 0;
scores.hyper_intensity = 0;
scores.hyper_score = 0;
scores.combined_score = 0;
scores.concern_area = 0;
final_hypo = zeros(std_size);
final_hyper = zeros(std_size);
final_abnormal = zeros(std_size);

original_img = imread(get_pathv2(pid, eye, time, 'original'));
if size(original_img,3) > 1
    original_img = rgb2gray(original_img);
end
original_img = imresize(original_img, [std_size std_size]);
original_img = im2double(original_img);

%Get intermediate data either by generating it or loading from file
file = ['./matfiles/',pid,'_',eye,'_',time,'.mat'];

if strcmp(status,'generate')
    %Find optic disk and vessels
    [od, vessels, angles, ~, gabor_img, avg_img, corrected_img] = find_od(pid, eye, time, 1, 'off');

    %Find fovea
	if ~any(od(:))
        [x_fov,y_fov] = find_fovea_no_od(vessels,angles,1);
	else
		[ x_fov,y_fov ] = find_fovea( vessels, angles, od, 1 );
	end
    
    if ~isdir('./matfiles')
        mkdir('./matfiles');
    end

    save(file,'od','vessels','gabor_img','avg_img','corrected_img','x_fov','y_fov');
else
    int_data = load(file);
    od = int_data.od;
    vessels = int_data.vessels;
    gabor_img = int_data.gabor_img;
    avg_img = int_data.avg_img;
    corrected_img = int_data.corrected_img;
    x_fov = int_data.x_fov;
    y_fov = int_data.y_fov;
end

%Show the user what's been detected so far
if debug == 2 || debug == 4
    combined_img = display_anatomy( original_img, od, vessels, x_fov, y_fov );
    figure(10), imshow(combined_img)
end

%----Detect regions of possible macular degeneration---------------
anatomy_mask = od | vessels;
insig = find_insig(gabor_img, avg_img, anatomy_mask, debug);
if debug == 4
    figure(11), imshow(insig)
end
not_amd = insig | anatomy_mask;
rois = find_possible_amd(not_amd,x_fov,y_fov,debug); 
if ~any(rois(:))
    disp('No AMD found!')
    e = cputime - t;
    disp(['Total [AMD] Processing Time (min): ', num2str(e/60.0)]);
    return
end

%---Run pixelwise classification of hypofluorescence-----
if debug >= 1
    disp('[HYPO] Finding areas of hypofluorescence');
end
%Load the classifier
model = load('hypo_classifier.mat', 'scaling_factors','classifier');
scaling_factors = model.scaling_factors;
classifier = model.classifier;

%combine with other data from optic disk detection, and exclude vessel or
%od or normal pixels
[ r ] = get_radial_dist( size(od), x_fov, y_fov );
feature_image = cat(3,gabor_img, avg_img,r);
instance_matrix = [];
for i = 1:size(feature_image,3)
    layer = feature_image(:,:,i);
    feature = layer(rois>0);
    instance_matrix = [instance_matrix, feature];
end

%Scale the vectors for input into the classifier
for i = 1:size(instance_matrix,2)
    fmin = scaling_factors(1,i);
    fmax = scaling_factors(2,i);
    instance_matrix(:,i) = (instance_matrix(:,i)-fmin)/(fmax-fmin);
end

%Run hypo classification
labeled_img = zeros(size(od));
[labeled_img(rois>0), ~, probabilities] = libsvmpredict(ones(length(instance_matrix),1), sparse(instance_matrix), classifier, '-q -b 1');
clear instance_matrix

prob_img = zeros(size(labeled_img));
prob_img(rois>0) = probabilities(:,classifier.Label==1);

final_hypo = GraphCutsHypo(logical(labeled_img), prob_img, cat(3,feature_image(:,:,1:size(gabor_img,3)),corrected_img));

if(debug == 2 || debug == 4)
    figure(12), imshow(display_outline(original_img, logical(labeled_img), [1 0 0]))
    figure(13), imshow(prob_img);
    figure(14), imshow(display_outline(original_img, logical(final_hypo), [1 0 0]));
end


%-----Run superpixelwise classification of hyperfluorescence-----
if debug >= 1
    disp('[HYPER] Finding areas of hyperfluorescence');
end

%get superpixels from intensity image
im = cat(3,corrected_img, corrected_img, corrected_img);
k = 1000;
m = 20;
seRadius = 1;
threshold = 4;
[insig, Am, Sp, ~] = slic(im, k, m, seRadius);
%cluster superpixels
lc = spdbscan(insig, Sp, Am, threshold);
%generate feature vectors for each labeled region
[~, Al] = regionadjacency(lc);
if any(final_hypo(:))
    hypo_input = final_hypo;
else 
    hypo_input = [x_fov,y_fov];
end
instance_matrix = get_fv_hyper(lc,Al,hypo_input,corrected_img);

%Load the classifier
model = load('hyper_classifier.mat', 'scaling_factors','classifier');
scaling_factors = model.scaling_factors;
classifier = model.classifier;

%Scale the vectors for input into the classifier
for i = 1:size(instance_matrix,2)
    fmin = scaling_factors(1,i);
    fmax = scaling_factors(2,i);
    instance_matrix(:,i) = (instance_matrix(:,i)-fmin)/(fmax-fmin);
end

classifications = libpredict(ones(length(instance_matrix),1), sparse(instance_matrix), classifier, '-q');
clear instance_matrix

final_hyper = zeros(size(corrected_img));
for i = 1:length(classifications)
    final_hyper(lc==i) = classifications(i);
end

final_hyper = logical(final_hyper);

if(debug == 2 || debug == 4)
    figure(15), imshow(display_outline(original_img, final_hyper, [1 1 0]));
end

%Get final outline of "concern" areas of abnormal retina
overlap = (rois>0)&(final_hyper|final_hypo);
if ~any(overlap(:))
    disp('No AMD found!')
    e = cputime - t;
    disp(['Total [AMD] Processing Time (min): ', num2str(e/60.0)]);
    return
else
    %check how much hyper or hypo is present in each abnormal region.  if
    %none do not put region in final mask
    for k = 1:max(rois(:))
        region = rois == k;
        overlap = sum(sum(region&(final_hyper|final_hypo)))/sum(sum(region));
        if overlap < .9 && overlap > 0
            convex = regionprops(region,'ConvexImage','BoundingBox');
            boxlimits = convex.BoundingBox;
            ul_x = round(boxlimits(1));
            ul_y = round(boxlimits(2));
            x_width = boxlimits(3);
            y_width = boxlimits(4);
            final_abnormal(ul_y:ul_y+y_width-1,ul_x:ul_x+x_width-1) = convex.ConvexImage;
        end
    end
end
final_abnormal = final_abnormal|final_hypo|final_hyper;

if(debug == 2 || debug == 4)
    out = display_outline(original_img, final_abnormal, [0 0 1]);
    out = display_outline(out,final_hypo,[1 0 0]);
    out = display_outline(out,final_hyper,[1 1 0]);
    figure(16), imshow(out)
end

%Generate quantification metrics
corrected_img = mat2gray(corrected_img);
scores = struct;
%1 pixel = 1e-4 mm^2
scores.hypo_area = sum(final_hypo(:))*1e-4;
scores.hypo_intensity = mean(corrected_img(final_hypo));
scores.hypo_score = (1-scores.hypo_intensity)*scores.hypo_area;
scores.hyper_area = sum(final_hyper(:))*1e-4;
scores.hyper_intensity = mean(corrected_img(final_hyper));
scores.hyper_score = scores.hyper_intensity*scores.hyper_area;
scores.combined_score = scores.hypo_score+scores.hyper_score;
scores.concern_area = sum(final_abnormal(:))*1e-4;

e = cputime - t;
disp(['Total [AMD] Processing Time (min): ', num2str(e/60.0)]);



