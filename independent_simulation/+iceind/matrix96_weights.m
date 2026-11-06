function w=matrix96_weights(x,y,dx,positions,elementSize)
%MATRIX96_WEIGHTS Conservative rectangular surface overlap, x-fast ordering.
w=zeros(numel(x)*numel(y),size(positions,1),'single');
for e=1:size(positions,1)
    wx=max(0,min(x+dx/2,positions(e,1)+elementSize(1)/2)- ...
        max(x-dx/2,positions(e,1)-elementSize(1)/2))/dx;
    wy=max(0,min(y+dx/2,positions(e,2)+elementSize(2)/2)- ...
        max(y-dx/2,positions(e,2)-elementSize(2)/2))/dx;
    area=wx(:)*wy(:)';w(:,e)=single(area(:));
end
assert(max(abs(sum(double(w),1)*dx^2-prod(elementSize)))<prod(elementSize)*1e-5, ...
    'iceind:ClippedArray','Array clipped by source grid.');
end
