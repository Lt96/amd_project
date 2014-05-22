function [rowFeatureVectors] = extractValidFeatureVectorsInRows(featureLayers, validityMask)
%[rowFeatureVectors] = EXTRACTVALIDFEATUREVECTORSINROWS(featureLayers, validityMask)
%   �˴���ʾ��ϸ˵��

num_of_layers = size(featureLayers, 3);

rowFeatureVectors = zeros(sum(validityMask(:)), num_of_layers);
for p = 1:num_of_layers
    currentLayer = featureLayers(:,:,p);
    rowFeatureVectors(:,p) = currentLayer(validityMask);
end

end

