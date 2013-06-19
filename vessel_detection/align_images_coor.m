function [result] = align_images_coor(img1, img2, quad_count, skip_quad)
    addpath('crosscoor');
    
    image1 = double(imread(img1))/256;
    image2 = double(imread(img2))/256;

    minx = min_axis(image1, image2, 1);
    miny = min_axis(image1, image2, 2);
    
    image1 = imresize(image1, [minx, miny]);
    image2 = imresize(image2, [minx, miny]);

    disp(['Running Correlation: ', img1, ' - ', img2]);
    cc = correlCorresp('image1', image1, 'image2', image2);%, 'printProgress', 100);
    cc.relThresh = 0.4;
    cc.convTol = 0.05; 
    cc = cc.findCorresps;
        
    %Get the most common points in each quad
    temp = most_common(cc.corresps, quad_count, skip_quad, minx, miny);

    %Display the original set of matched points
    figure(1);
    correspDisplay(cc.corresps, image1);
    
    %Displat the subset of polled mathced points
    figure(2);
    correspDisplay(temp, image1);
    
    %Form arry in the correct manner
    pointsA = temp(1:2,:)';
    pointsB = temp(3:4,:)';
   
    %Estimate the image transform
    [theta, scale, translation, tform] = transform_it(pointsA, pointsB);
    
    disp(['Correcting Image: theta: ' , num2str(theta), ' scale: ', num2str(scale), ...
            ' x: ', num2str(translation(1)), ' y: ', num2str(translation(2))]);
    
    result = tform;
end

function [out] = min_axis(img1, img2, dim)
    min = size(img1, dim);
    
    if(size(img2, dim) < min)
       min =  size(img2, dim);
    end
    
    out = min;
end