%PAIROPTIONS class definition
%
%   Usage:
%      pairoptions=pairoptions();
%      pairoptions=pairoptions('module',true,'solver',false);

classdef pairoptions < handle
	properties (SetAccess = private,GetAccess = private) 
		functionname = '';
		list         = cell(0,3);
	end
	methods
		function obj = pairoptions(varargin) % {{{

			%get calling function name
			a=dbstack;
			if length(a)>1,
				obj.functionname=a(2).file(1:end-2);
			else
				obj.functionname='';
			end

			%initialize list
			if nargin==0,
				%Do nothing,
			else
				obj=buildlist(obj,varargin{:});
			end
		end % }}}
		function obj = buildlist(obj,varargin) % {{{
		%BUILDLIST - build list of obj from input

			%check length of input
			if mod((nargin-1),2),
				error('Invalid parameter/value pair arguments') 
			end
			numoptions = (nargin-1)/2;

			%Allocate memory
			obj.list=cell(numoptions,3);

			%go through varargin and build list of obj
			for i=1:numoptions,
				if ischar(varargin{2*i-1}),
					obj.list{i,1}=varargin{2*i-1};
					obj.list{i,2}=varargin{2*i};
					obj.list{i,3}=false; %used?
				else
					%option is not a string, ignore it
					disp(['WARNING: option number ' num2str(i) ' is not a string, it will be ignored']);
					obj.list(i,:)=[];
					continue
				end
			end
		end % }}}
		function obj = addfield(obj,field,value) % {{{
			if ischar(field),
				obj.list{end+1,1} = field;
				obj.list{end,2}   = value;
				obj.list{end,3}   = false;
			end
		end % }}}
		function obj = addfielddefault(obj,field,value) % {{{
		%ADDFIELDDEFAULT - add a field to an options list if it does not exist
			if ischar(field),
				if ~exist(obj,field),
					obj.list{end+1,1} = field;
					obj.list{end,2}   = value;
					obj.list{end,3}   = true;  %It is a default so user will not be notified if not used
				end
			end
		end % }}}
		function obj2 = AssignObjectFields(options,obj2) % {{{
		%ASSIGNOBJECTFIELDS - assign object fields from options
			listproperties=properties(obj2);
			for i=1:size(options.list,1),
				fieldname=options.list{i,1};
				fieldvalue=options.list{i,2};
				if ismember(fieldname,listproperties),
					obj2.(fieldname)=fieldvalue;
				else
					disp(['WARNING: ''' fieldname ''' is not a property of ''' class(obj2) '''']);
				end
			end
		end % }}}
		function obj = changefieldvalue(obj,field,newvalue) % {{{
		%CHANGEOPTIONVALUE - change the value of an option in an option list

			%track occurrence of field
			lines=find(strcmpi(obj.list(:,1),field));

			%replace value
			if isempty(lines),
				%add new field if not found
				obj=addfield(obj,field,newvalue);
				obj.list{end,3}=true; % do not notify user if unused
			else
				for i=1:length(lines),
					obj.list{lines(i),2}=newvalue;
				end
			end
		end % }}}
		function obj = deleteduplicates(obj,warn) % {{{
		%DELETEDUPLICATES - delete duplicates in an option list

			%track the first occurrence of each option
			[dummy lines]=unique(obj.list(:,1),'first');
			clear dummy

			%warn user if requested
			if warn,
				numoptions=size(obj.list,1);
				for i=1:numoptions,
					if ~ismember(i,lines),
						disp(['WARNING: option ' obj.list{i,1} ' appeared more than once. Only its first occurrence will be kept'])
					end
				end
			end

			%remove duplicates from the options list
			obj.list=obj.list(lines,:);
		end % }}}
		function displayunused(obj) % {{{
			%DISPLAYUNUSED - display unused options

			numoptions=size(obj.list,1);
			for i=1:numoptions,
				if ~obj.list{i,3},
					disp(['WARNING: option ' obj.list{i,1} ' was not used'])
				end
			end
		end % }}}
		function disp(obj) % {{{
			disp(sprintf('   functionname: %s',obj.functionname));
			if ~isempty(obj.list),
				disp(sprintf('   list: (%ix%i)\n',size(obj.list,1),size(obj.list,2)));
				for i=1:size(obj.list,1),
					if ischar(obj.list{i,2}),
						disp(sprintf('     field: %-10s value: ''%s''',obj.list{i,1},obj.list{i,2}));
					elseif isnumeric(obj.list{i,2}) & length(obj.list{i,2})==1,
						disp(sprintf('     field: %-10s value: %g',obj.list{i,1},obj.list{i,2}));
					elseif isnumeric(obj.list{i,2}) & length(obj.list{i,2})==2,
						disp(sprintf('     field: %-10s value: [%g %g]',obj.list{i,1},obj.list{i,2}));
					else
						disp(sprintf('     field: %-10s value: (%ix%i)',obj.list{i,1},size(obj.list{i,2},1),size(obj.list{i,2},2)));
					end
				end
			else
				disp(sprintf('   list: empty'));
			end
		end % }}}
		function bool = exist(obj,field) % {{{
		%EXIST - check if the option exists

			%some argument checking: 
			if ((nargin~=2) | (nargout~=1)),
				error('exist error message: bad usage');
			end
			if ~ischar(field),
				error('exist error message: field should be a string');
			end

			%Recover option
			pos=find(strcmpi(field,obj.list(:,1)));
			if ~isempty(pos),
				bool=true;
				obj.list{pos,3}   = true;  %It is a default so user will not be notified if not used
			else
				bool=false;
			end
		end % }}}
		function num = fieldoccurrences(obj,field), % {{{
		%FIELDOCCURRENCES - get number of occurrence of a field

			%check input 
			if ~ischar(field),
				error('fieldoccurrences error message: field should be a string');
			end

			%get number of occurrence
			num=sum(strcmpi(field,obj.list(:,1)));
		end % }}}
		function value = getfieldvalue(obj,field,varargin), % {{{
		%GETOPTION - get the value of an option
		%
		%   Usage:
		%      value=getfieldvalue(obj,field,varargin)
		%
		%   Find an option value from a field. A default option
		%   can be given in input if the field does not exist
		%
		%   Examples:
		%      value=getfieldvalue(options,'caxis');
		%      value=getfieldvalue(options,'caxis',[0 2]);

			%some argument checking: 
			if nargin~=2 && nargin~=3,
				help getfieldvalue
				error('getfieldvalue error message: bad usage');
			end

			if ~ischar(field),
				error('getfieldvalue error message: field should be a string');
			end

			%Recover option
			pos=find(strcmpi(obj.list(:,1),field));
			if ~isempty(pos),
				value=obj.list{pos(1),2}; % ignore extra entry
				obj.list{pos(1),3}=true;  % option used
				return;
			end

			%The option has not been found, output default if provided
			if nargin==3,
				value=varargin{1};
			else
				error(['error message: field ' field ' has not been provided by user (and no default value has been specified)'])
			end
		end % }}}
		function obj = removefield(obj,field,warn)% {{{
		%REMOVEFIELD - delete a field in an option list
		%
		%   Usage:
		%      obj=removefield(obj,field,warn)
		%
		%   if warn==1 display an info message to warn user that
		%   some of his options have been removed.

			%check is field exist
			if exist(obj,field),

				%find where the field is located
				lines=find(~strcmpi(obj.list(:,1),field));

				%remove duplicates from the options list
				obj.list=obj.list(lines,:);

				%warn user if requested
				if warn
					disp(['removefield info: option ' field ' has been removed from the list of options.'])
				end
			end
		end % }}}
		function marshall(obj,fid,firstindex)% {{{

			for i=1:size(obj.list,1),
				name  = obj.list{i,1};
				value = obj.list{i,2};

				%Write option name
				WriteData(fid,'enum',(firstindex-1)+2*i-1,'data',name,'format','String');

				%Write option value
				if (isnumeric(value) & numel(value)==1),
					WriteData(fid,'enum',(firstindex-1)+2*i,'data',value,'format','Double');
				elseif ischar(value),
					WriteData(fid,'enum',(firstindex-1)+2*i,'data',value,'format','String');
				else
					error(['Cannot marshall option ' name ': format not supported yet']);
				end
			end
		end % }}}
	end
end
