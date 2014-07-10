function [rows] = reorganizeLayeredImgFeatures2RowFeatureVectors(stackMxs)
%[rows]=ORGANIZEMX2ROW(stackMxs)
%   converts a 3d matrix of [m��n��p] to a 2d matrix of [(mn)��p]

[m, n, p] = size(stackMxs);
rows = zeros(m*n, p);
for i = 1:p
   rows(:, i) = reshape(stackMxs(:,:,i), m*n, 1); 
end

end

