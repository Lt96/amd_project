function [ g ] = splitmerge(f, mindim, fun )
%*******ADAPTED FROM GONZALEZ, WOODS "DIGITAL IMAGE PROCESSING IN MATLAB"
% FIFTH EDITION, 2009 - FUNCTION SPLITMERGE ON PG 428***********
%
% G = SPLITMERGE(F, MINDIM, @PREDICATE) segments image F using
% split=and-merge based on quad tree decomposition.  MINDIM (positive
% integer power of 2) specifies the minimum allowed dimension of the quadtree
% regions.  If necessary, the function pads the image with zeros to the
% nearest square size that is an integer power of 2.  The result is cropped
% back to the original size of the input image.  In the output, G, each
% connected region is labeled with a different integer.
%
% PREDICATE is a function in the MATLAB path provided by the user.  Its
% syntax is FLAG = PREDICATE(REGION)

%Pad image with zeros to guarantee that function qtdecomp will split
%regions down to size 1-by-1.
Q = 2^nextpow2(max(size(f)));
[M, N] = size(f);
f = padarray(f, [Q-M, Q-N], 'post');

%Perform splitting
S= qtdecomp(f, @split_test, mindim, f, fun);

%Now Merge by looking at each quadregion and setting all its lements to 1 if
%the block satisfies the predicate.
Lmax =  full(max(S(:)));
g = zeros(size(f));
for K = 1:Lmax
    [vals, r, c] = qtgetblk(f, S, K);
    if ~isempty(vals)
        %Check the predicate for each of the regions of size K-by-K with
        %coordinates given by vectors r and c.
        for I = 1:length(r)
            xlow = r(I); ylow = c(I);
            xhigh = xlow + K - 1; yhigh = ylow + K - 1;
            region = f(xlow:xhigh, ylow:yhigh);
            flag = feval(fun, region, f);
            if flag
                g(xlow:xhigh, ylow:yhigh)  = 1;
            end
        end
    end
end

%Label each connected region 
g = bwlabel(g);

%Crop and exit
g = g(1:M, 1:N);
end

%------------------------------------------------------------------------
function v = split_test(B, mindim, f, fun)
    %Determines whether quadregions are split.  Returns in v logical 1s for
    %the blocks that should be split and logical 0s for those that should
    %not.
    
    k = size(B,3); %number of regions in B at this step
    
    v(1:k) = false;
    for I = 1:k
        quadregion = B(:,:,I);
        if size(quadregion, 1) <= mindim
            v(I) = false;
            continue
        end
        flag = feval(fun, quadregion, f);
        if ~flag
            v(I) = true;
        end
    end
end

