function [ cropped_img ] = crop_footer( img )
% Removes footer from grayscale FAF image matrices 

i = round(size(img,1)/2); % start at middle
while any(img(i,:))
    if i == size(img,1)
       cropped_img = img;
       return
    else
    i = i+1;
    end
end

cropped_img = img(1:i-1,:);

end

