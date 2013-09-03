function [out] = vessel_detection_curvlet(I)    
    if length(size(I)) > 2
        I = rgb2gray(I);
    end
    
    I = double(I);

    %Calculate the Curvlet coefficients
    C = fdct_wrapping(I, 0);

    %Get a zeroed out version of the Coefficients matrix
    ctemp = C;
    for j=1:length(ctemp)
        for l=1:length(ctemp{j})
            for y=1:size(ctemp{j}{l}, 1)
                for x=1:size(ctemp{j}{l}, 2)
                   ctemp{j}{l}(y, x) = 0;                         
                end
            end
        end
    end

    %Curvlet coefficients that must be modified
    lemma = .5;
    c = 3;
    p = .5;
    s = 0;
    
    %Modify the Curvlet coefficients
    C = modify_coefficients(C, ctemp, lemma, c, p, s);

    %Rebuild the image using the modified coefficient values
    Y = mat2gray(real(ifdct_wrapping(C, 0)));
    disp('----------------------------------------------------------');
    
    %Allocate the output image to sum up morpholocigcal filters
    final_img = zeros(size(I,1), size(I,2));
    
    %Combine all the images into a final image using each structuring element
    M = 8;
    length_element = 5;
    wedge = 180 / M;
    for i=1:M
        line = strel('line', length_element, i * wedge);
        final_img = add_img(apply_morph(Y, line), M, final_img);
    end
    
    figure(1);
    imshow(final_img);
    
    figure(2);
    subplot(1,2,1); colormap gray; imagesc(real(I)); axis('image'); title('original image');
    subplot(1,2,2); colormap gray; imagesc(real(Y)); axis('image'); title('partial reconstruction');

    out = final_img;
end

function [newCoeff] = modify_coefficients(C, ctemp, lemma, c, p, s)
    newCoeff = C;
    
    %Loop through each scale|angle
    for j=1:length(C)
        for l=1:length(C{j})
            disp(['Scale: ', num2str(j), ' Angle: ', num2str(l)]);
            
            %Set the empty coefficient array to current scale|angle
            for y=1:size(C{j}{l}, 1)
                for x=1:size(C{j}{l}, 2)
                    ctemp{j}{l}(y, x) = C{j}{l}(y, x);
                end
            end

            %Rebuild the image using only one angle and scale at a time
            ctempimg = real(ifdct_wrapping(ctemp, 0));

            %Reset the coefficient array to empty
            for y=1:size(C{j}{l}, 1)
                for x=1:size(C{j}{l}, 2)
                    ctemp{j}{l}(y, x) = 0;
                end
            end
            
            %Estimate the noise image standard deviation for this sub-band
            sigma = img_stddev(ctempimg);
            
            %Find the maximum value within this scale and angle
            Mij = max(C{j}{l}(:));

            %calculate the m value for the peacewise function shown in equation(7)
            %m = lemma * (Mij - sigma);
            m = Mij * lemma;
            
            %Apply the yalpha function to each coefficient in this scale and angle wedge
            newCoeff{j}{l} = process_subband_matrix(C{j}{l}, sigma, m, c, p, s);
        end
    end
end

function [sigma] = img_stddev(img)
    %This method was developed using the following paper
    % WAVELET IMAGE DE-NOISING METHOD BASED ON NOISE STANDARD DEVIATION ESTIMATION
    
    %Define the noise estimation template as the difference between two
    %LaPlace templates
    M = [ 1,-2, 1;
         -2, 4,-2;
          1,-2, 1];
      
    %Convolve the noise estimation matrix with the image
    convolve = conv2(img, M);
    
    %Get the sum of the absolutue value of the matrix from the convolution
    convoluve_abs = abs(convolve);
    summation = sum(convoluve_abs(:));
    
    %k and l is the image height and image width
    k = size(img, 2);
    l = size(img, 1);
    
    %Calculate the standard deviation from the main 
    sigma = sqrt(pi / 2) * (1 / (6 * (k - 2) * (l - 2))) * summation;
end

function [result] = process_subband_matrix(CoeffMatrix, sigma, m, c, p, s)
    %For each sub matrix find the maximum value and use it to calculate
    %variable m (lowercase), this is based upon the following paper.
    %Fast and automatic algorithm for optic disc extraction in
    %   retinal images using principle-component-analysis-based
    %   preprocessing and curvelet transform
    
    %Loop on each value within the CoeffMatrix and apply the yalpha function
    %the yalpha function returns a multiplication value
    for y=1:size(CoeffMatrix, 1)
        for x=1:size(CoeffMatrix, 2)
            CoeffValue = CoeffMatrix(y, x);
            modify_coeff = yalpha(abs(CoeffValue), sigma, m, c, p, s);
            CoeffMatrix(y, x) = CoeffValue * modify_coeff;
        end
    end
    
    %set output variable to the results from the modified matrix
    result = CoeffMatrix;
end

function [result] = yalpha(x, sigma, m, c, p, s)
    %This is the definition of the peacewise function as described in
    %"Gray and Color Image Contrast Enhancement by the Curvelet Transform"
    %Authors: Jean-Luc Starck, Fionn Murtagh, Emmanuel J. Cand�s, and David L. Donoho
    if (abs(x) < (c*sigma))
        result = 1;
    elseif ((c*sigma) <= abs(x) && abs(x) < (2*c*sigma))
        result = (((abs(x) - (c*sigma)) / (c*sigma)) * ((m / (c*sigma))^p)) + (((2*c*sigma) - abs(x)) / (c*sigma));
    elseif ((2*c*sigma) <= abs(x) && abs(x) < m)
        result = ((m / abs(x))^p);
    elseif (m <= abs(x))
        result = ((m / abs(x))^s);
    else
        result = 0;
        disp('Error in yalpha peacewise function');
    end
end

function [finalimg] = add_img(inputimg, M, finalimg)
    if size(inputimg, 1) == size(finalimg, 1) && ...
       size(inputimg, 2) == size(finalimg, 2)
        for y=1:size(inputimg, 1)
            for x=1:size(inputimg, 2)
                finalimg(y, x) = finalimg(y, x) + (inputimg(y, x) / M);
            end
        end
    else
        disp('Incorrect SIZE');
    end
end

function [out] = apply_morph(img, strelement)
    newimg = imclose(img, strelement);
    newimg = imopen(newimg, strelement);
    
    newimg1 = imdilate(newimg, strelement);
    newimg2 = imerode(newimg, strelement);
    
    out = imsubtract(newimg1, newimg2);
end

