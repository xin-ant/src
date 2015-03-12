function overlay(x,y,data,varargin);

%Process options
options=pairoptions(varargin{:});

%convert to double
x = double(x);
y = double(y);
data=double(data);
data_grid=double(data);

[data_nani data_nanj]=find(isnan(data_grid) | data_grid==-9999);
if exist(options,'caxis'),
	caxis_opt=getfieldvalue(options,'caxis');
	data_grid(find(data_grid<caxis_opt(1)))=caxis_opt(1);
	data_grid(find(data_grid>caxis_opt(2)))=caxis_opt(2);
	data_min=caxis_opt(1);
	data_max=caxis_opt(2);
else
	data_min=min(data_grid(:));
	data_max=max(data_grid(:));
end

colorm = getcolormap(options);
len    = size(colorm,1);
if 0,
	ind = ceil((len-1)*(data_grid-data_min)/(data_max - data_min + eps)+1);
	ind(find(ind>len))=len;
	image_rgb=zeros(size(data_grid,1),size(data_grid,2),3);
	r=colorm(:,1); image_rgb(:,:,1)=r(ind); clear r;
	g=colorm(:,2); image_rgb(:,:,2)=g(ind); clear g;
	b=colorm(:,3); image_rgb(:,:,3)=b(ind); clear b;
else
	image_rgb = ind2rgb(uint16((data_grid - data_min)*(length(colorm)/(data_max-data_min))),colorm);
end

if exist(options,'shaded'),
	a    = -45;
	scut = 0.2;
	c    = 1;
	% computes lighting from elevation gradient
	[fx,fy] = gradient(data,x,y);
	fxy = -fx*sind(a) - fy*cosd(a);
	clear fx fy	% free some memory...
	fxy(isnan(fxy)) = 0;

	% computes maximum absolute gradient (median-style), normalizes, saturates and duplicates in 3-D matrix
	r = repmat(max(min(fxy/nmedian(abs(fxy),1 - scut/100),1),-1),[1,1,3]);

	% applies contrast using exponent
	rp = (1 - abs(r)).^c;
	image_rgb = image_rgb.*rp;

	% lighter for positive gradient
	k = find(r > 0);
	image_rgb(k) = image_rgb(k) + (1 - rp(k));
end
% set novalues / NaN to black color
if ~isempty(data_nani)
	nancolor=getfieldvalue(options,'nancolor',[0 0 0]);
	image_rgb(sub2ind(size(image_rgb),repmat(data_nani,1,3),repmat(data_nanj,1,3),repmat(1:3,size(data_nani,1),1))) = repmat(nancolor,size(data_nani,1),1);
end

if exist(options,'zerocolor'),
	[data_zeroi data_zeroj]=find(data_grid==0);
	zerocolor=getfieldvalue(options,'zerocolor',[1 1 1]);
	if ~isempty(data_zeroi)
		image_rgb(sub2ind(size(image_rgb),repmat(data_zeroi,1,3),repmat(data_zeroj,1,3),repmat(1:3,size(data_zeroi,1),1))) = repmat(zerocolor,size(data_zeroi,1),1);
	end
end

%frame
if exist(options,'frame'),
	width=getfieldvalue(options,'frame');
	image_rgb(1:width,:,:)=0;
	image_rgb(:,1:width,:)=0;
	image_rgb(end-width+1:end,:,:)=0;
	image_rgb(:,end-width+1:end,:)=0;
end

%greysquares
if exist(options,'greysquares'),
	coords = getfieldvalue(options,'greysquares');
	[X Y]=meshgrid(x,y);
	for i=1:size(coords,1);
		x0 = coords(i,1);      y0 = coords(i,2);
		x1 = x0 + coords(i,3); y1 = y0 + coords(i,3);
		[pos]       = find(X<x1 & X>x0 & Y<y1 & Y>y0);
		[posi posj] = ind2sub(size(X),pos);

		alpha = .6;
		color = getfieldvalue(options,'greycolor',[1 1 1]);

		r = image_rgb(:,:,1);  r(pos) = (1-alpha)*r(pos) + alpha*color(1); image_rgb(:,:,1) = r;  clear r;
		g = image_rgb(:,:,2);  g(pos) = (1-alpha)*g(pos) + alpha*color(2); image_rgb(:,:,2) = g;  clear g;
		b = image_rgb(:,:,3);  b(pos) = (1-alpha)*b(pos) + alpha*color(3); image_rgb(:,:,3) = b;  clear b;

		%black border
		posimin = min(posi); posimax=max(posi); posilength = posimax-posimin;
		posjmin = min(posj); posjmax=max(posj); posjlength = posjmax-posjmin;
		r = image_rgb(:,:,1);
		r(posimin,posjmin:posjmax) = 0; r(posimax,posjmin:posjmax) = 0; r(posimin:posimax,posjmin) = 0; r(posimin:posimax,posjmax) = 0; 
		image_rgb(:,:,1) = r;  clear r;
		g = image_rgb(:,:,2);
		g(posimin,posjmin:posjmax) = 0; g(posimax,posjmin:posjmax) = 0; g(posimin:posimax,posjmin) = 0; g(posimin:posimax,posjmax) = 0; 
		image_rgb(:,:,2) = g;  clear g;
		b = image_rgb(:,:,3);
		b(posimin,posjmin:posjmax) = 0; b(posimax,posjmin:posjmax) = 0; b(posimin:posimax,posjmin) = 0; b(posimin:posimax,posjmax) = 0; 
		image_rgb(:,:,3) = b;  clear b;

	end
end

ALPHA=ones(size(data_grid));
ALPHA(sub2ind(size(ALPHA),repmat(data_nani,1,2),repmat(data_nanj,1,2)))=0;
if 1,
	%Start with xlim and ylim otherwise akpha does not work (everything disappears)
	xlim([min(x) max(x)]); ylim([min(y) max(y)]);
	h=imagesc(x,y,image_rgb);

	%set(h,'AlphaData', ALPHA);
	axis equal off xy
	caxis([data_min data_max]);
	colormap(colorm);
	xlim([min(x) max(x)]); ylim([min(y) max(y)]);
	imwrite(flipdim(image_rgb,1),'temp.png','alpha',flipdim(ALPHA,1));
else
	tic
	imwrite(flipdim(image_rgb,1),'temp.png','alpha',flipdim(ALPHA,1));
	toc
end

function y = nmedian(x,n)
%NMEDIAN Generalized median filter
%	NMEDIAN(X,N) sorts elemets of X and returns N-th value (N normalized).
%	So:
%	   N = 0 is minimum value
%	   N = 0.5 is median value
%	   N = 1 is maximum value

if nargin < 2
	n = 0.5;
end
y = sort(x(:));
y = interp1(sort(y),n*(length(y)-1) + 1);
