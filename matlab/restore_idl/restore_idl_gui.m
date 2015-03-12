function varargout = restore_idl_gui(varargin)
% RESTORE_IDL_GUI MATLAB code for restore_idl_gui.fig
%
% Allows restoring variables from an IDL save file.  Variables are
% restored into the Matlab base workspace.  Option to change names of 
% created variables to lowercase.
%
% How to use:
%
% Click "Choose IDL File" - use file browser to identify the IDL save file.
%  Variables in the IDL file will be listed
%  indicating their data type (scalar, array, structure, uint8, float32, 
%  etc.); and for arrays, their dimensions. 
%
% Select one or more variables in the display listbox (shift-click,
%  control-click, etc. for multiple selection)
%
% Choose "Convert names to lowercase" if desired.  Variables are saved with
% names (and structure field names) in ALL CAPS so if you find that
% annoying, click the handy checkbox (actually it's checked by default 
% because I find it annoying).
%
% Click "Restore Selected" - chosen variables will be created in the base 
%  Matlab workspace.
%
% Capabilities:
%  Can process all basic IDL numeric, array, string and structure data 
%  types.  Does NOT restore object references. Does NOT understand ulong64 
%  offsets, thus cannot process files >4GB.  
%
%  Structures with fields that are arrays or other structures
%  are handled via recursion.  This structures within structures feature
%  has not been thoroughly tested - only to one level of nesting.  Known to
%  work properly with save files from IDL version 8.1.  Since the file
%  format description used to develop the code is several years old (see
%  link below), probably will work with files from earlier versions as
%  well. 
%
% C. Pelizzari Oct 2013
%   initial version - doesn't handle structures
%   version 1.1 - handles structures, including fields which are arrays or
%   structures (nested structures).
%
%   jan 2014:  fix problem with structures that contain multiple arrays.
%   only one data start code (32 bit int "7") for all the data in the 
%   structure, not one per array.  
%   so read_idl_array has be told not to read the
%   startcode when inside a structure.
%
% Based on description of IDL save file format by Craig Markwardt:
%
%   http://www.physics.wisc.edu/~craigm/idl/savefmt/  
%
%
% (c) 2013, University of Chicago Image Computing, Analysis and Repository 
%  (ICAR) Core Facility

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @restore_idl_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @restore_idl_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before restore_idl_gui is made visible.
function restore_idl_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to restore_idl_gui (see VARARGIN)

% Choose default command line output for restore_idl_gui
handles.output = hObject;
set(handles.figure1,'Name',...
    'Restore IDL GUI: U of Chicago ICAR, Version 20140130');
% Update handles structure
handles.pathname='./';
guidata(hObject, handles);



% --- Outputs from this function are returned to the command line.
function varargout = restore_idl_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in FileSelectButton.
function FileSelectButton_Callback(hObject, eventdata, handles)
% hObject    handle to FileSelectButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

verbose = get(handles.VerboseCheckbox,'Value');
% get file selection
[fname,pathname]=uigetfile(fullfile(handles.pathname,'*.*'),...
    'Select IDL save file to restore');
if ~fname, return, end;
if verbose, disp(fullfile(pathname,fname));end
% put file path into text box on UI panel
set(handles.FileNameText,'String',fullfile(pathname,fname));
handles.pathname=pathname;
% open the file
fid=fopen(fullfile(pathname,fname),'rb');
signature=char(fread(fid,2,'char')');
if verbose, disp(['SIGNATURE = ' signature]); end
alldone=0;
% variables is a struct array that contains info about each variable found
variables=[];

% bail out if not a file we understand
 if ~strcmp(signature,'SR'),
    disp(['unrecognized signature - returning.']);
    fclose(fid);
    return;
 end
 
% cell array of strings to put into selection list box
handles.varnames={};

recfmts={'COMMON_VARIABLE' 'VARIABLE' 'SYSTEM_VARIABLE' '' '' 'END_MARKER' ...
    '' '' '' 'TIMESTAMP' '' 'COMPILED' 'IDENTIFICATION' 'VERSION' ...
    'HEAP_HEADER' 'HEAP_DATA' 'PROMOTE64' '' 'NOTICE'};

if verbose, % print out summary of structure of the file
    disp('----- Analysis of file structure: -----'); 
    nextptr=4; % start on longword boundary
    while(1)
        fseek(fid,nextptr,'bof');
        recfmt=fread(fid,1,'uint32',0,'b'); % see what kind of record we have
        fprintf(1,'Offset %d: record type %s\n', nextptr,recfmts{recfmt});
        if recfmt==6, break, end % end record - we're done
        nextptr=fread(fid,1,'uint32',0,'b');

    end
    disp('----------');
end
% now go through and save some info about each record
nextptr=4;
while (1)
    fseek(fid,nextptr,'bof');
    thisptr=nextptr;
    rhdr=fread(fid,1,'uint32',0,'b');
    if feof(fid), break; end % bail out if hit EOF
    nextptr=fread(fid,1,'uint32',0,'b');
    nextptr1=fread(fid,1,'uint32',0,'b');
    unknown=fread(fid,1,'uint32');
    
    % specific format of each type of record is documented in C. Markwardt's
    % description of the file format   
    switch rhdr
        case 10    %timestamp
            unknown=fread(fid,256,'uint32');
            strlen=fread(fid,1,'uint32',0,'b');
            datestring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            strlen=fread(fid,1,'uint32',0,'b');
            userstring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            strlen=fread(fid,1,'uint32',0,'b');
            hoststring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            if verbose,
            disp(['TIMESTAMP:  date, user, host =  ' datestring '  ' userstring '  ' hoststring])
            end
        case 14    % version       
            fmt=fread(fid,1,'uint32',0,'b');
            strlen=fread(fid,1,'uint32',0,'b');
            archstring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            strlen=fread(fid,1,'uint32',0,'b');
            osstring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            strlen=fread(fid,1,'uint32',0,'b');
            releasestring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
            if verbose,
            disp(['VERSION: arch, os, release = ' archstring osstring releasestring])
            end
        case 19
            if verbose, disp('NOTICE:'); end
            strlen=fread(fid,1,'uint32',0,'b');
            notestring=strtrim(char(fread(fid,4*ceil(strlen/4),'char')'));
        case 2  % this is the most important one - actual data
            varstring='';
            % here's the name - length first, then the string
            strlen=fread(fid,1,'uint32',0,'b');
            varname=deblank(char(fread(fid,4*ceil(strlen/4),'char')'));
            variables(end+1).name=varname;
            variables(end).ptr=thisptr;
            % typecode tells type of each element in variable
            typecode=fread(fid,1,'uint32',0,'b');
            % varflags tells if it's an array or scalar
            varflags=fread(fid,1,'uint32',0,'b');
            switch typecode
                case 1
                    mytype='uint8';
                case 2
                    mytype='int16';
                case 3
                    mytype='int32';
                case 4
                    mytype='single';
                case 5
                    mytype='double';
                case 6
                    mytype='complex';
                case 7
                    mytype='string';
                case 8
                    mytype='structure';
                case 9
                    mytype='double complex';
                case 11
                    mytype='object pointer';
                case 12
                    mytype='uint16';
                case 13
                    mytype='uint32';
                case 14
                    mytype='int64';
                case 15
                    mytype='uint64';
            end
            % varstring is our description for the selection listbox
            varstring=[ varname ':  '  mytype];
            %disp(varstring);
                   
                if ~bitand(varflags,4),  % scalar
                    %disp('    SCALAR ');
                    varstring=[varstring ' SCALAR'];
                    disp(varstring);
                elseif bitand(varflags, 4)  % array
                    %disp('ARRAY ')                   
                    arrstart=fread(fid,1,'uint32',0,'b');
                    nbytes_el=fread(fid,1,'uint32',0,'b');
                    nbytes=fread(fid,1,'uint32',0,'b');
                    nelements=fread(fid,1,'uint32',0,'b');
                    ndims=fread(fid,1,'uint32',0,'b');
                    stuff=fread(fid,2,'uint32',0,'b');
                    nmax=fread(fid,1,'uint32',0,'b');
                    dims=fread(fid,nmax,'uint32',0,'b')';
                    varstring=[varstring '  ARRAY: ' num2str(dims(1:max([2 ndims])))];
                    
                end
                if verbose, disp(varstring), end
            handles.varnames{end+1}=varstring;
        case 6
            if verbose, disp('END'); end
            break

        otherwise
            break;
    end
end
fclose(fid);
handles.variables=variables;
set(handles.VariablesBox,'String',handles.varnames);
set(handles.VariablesBox,'Min',1,'Max',numel(variables));
set(handles.VariablesBox,'Value',1);
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function VariablesBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to VariablesBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in RestoreButton.
function RestoreButton_Callback(hObject, eventdata, handles)
% hObject    handle to RestoreButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% global thevar makes our variable accessible in the base workspace.  this
% is the trick we use to copy it into a new variable in that workspace.

global thevar

% get user choice of variables to restore
verbose=get(handles.VerboseCheckbox,'Value');
dolower=get(handles.LowerCaseCheckbox,'Value');
choices=get(handles.VariablesBox,'Value');
if ~numel(choices), return, end;
% process each user choice - restore the variable if we understand how
fid=fopen(get(handles.FileNameText,'String'));
for whichone=choices,
    % point to proper place in file
    nextptr=handles.variables(whichone).ptr;
    % go there
    fseek(fid,nextptr,'bof');
    thisptr=nextptr;
    % read the record header
    rhdr=fread(fid,1,'uint32',0,'b');
    %if feof(fid), break; end
    nextptr=fread(fid,1,'uint32',0,'b');
    nextptr1=fread(fid,1,'uint32',0,'b');
    unknown=fread(fid,1,'uint32');
    switch rhdr
       case 2 % variable record - read in some data and create a variable
            varstring='';
            strlen=fread(fid,1,'uint32',0,'b');
            varname=deblank(char(fread(fid,4*ceil(strlen/4),'char')'));
            
            % convert to lowercase for Matlab variable naming if desired
            if dolower, varname=lower(varname); end
            
            typecode=fread(fid,1,'uint32',0,'b');
            varflags=fread(fid,1,'uint32',0,'b');
            switch typecode
                case 1
                    mytype='uint8';
                case 2
                    mytype='int16';
                case 3
                    mytype='int32';
                case 4
                    mytype='single';
                case 5
                    mytype='double';
                case 6
                    mytype='complex';
                case 7
                    mytype='string';
                case 8
                    mytype='structure';
                case 9
                    mytype='double complex';
                case 11
                    mytype='object pointer';
                case 12
                    mytype='uint16';
                case 13
                    mytype='uint32';
                case 14
                    mytype='int64';
                case 15
                    mytype='uint64';
            end
            varstring=[ varname ':  '  mytype];
            thevar = [];
            if ~bitand(varflags,4),  % scalar
                %disp('    SCALAR ');
                varstring=[varstring ' SCALAR'];

                thevar=read_idl_scalar(fid,typecode);
                if ~isempty(thevar),
                    
                        disp(['creating ' varstring]);
                   
                    thecommand= ['global thevar; ' varname ' = thevar;'];
                    evalin('base',thecommand);
                end
            elseif bitand(varflags, 4)  % array (includes structures)
                thevar=[];
                arrdesc = parse_array_descriptor(fid);
                dims=arrdesc.dims;
                ndims=arrdesc.ndims;

                varstring=[varstring '  ARRAY: ' num2str(dims(1:max([2 ndims])))];
                thevar=read_idl_array(fid,arrdesc,typecode,dolower);
                if ~isempty(thevar),
                    
                        disp(['creating ' varstring]);
                    
                    thevar= reshape(thevar,dims(1:max([2 ndims])));
                    thecommand=['global thevar; ' varname ' = squeeze(thevar);'];
                    evalin('base', thecommand);

                end

            end
            if verbose,
                if numel(thevar) <= 20, thevar, end, 
            end
        otherwise
            % not a variable record, nothing for us to do
    end
end
fclose(fid);


function mytype = idl_element_type( typecode)
%IDL_ELEMENT_TYPE
%   returns the string descriptor ('float32','int16', etc) given an IDL
%   typecode (a number from 1-15)

    switch typecode
        case 1
            mytype='uint8';
        case 2
            mytype='int16';
        case 3
            mytype='int32';
        case 4
            mytype='single';
        case 5
            mytype='double';
        case 6
            mytype='complex';
        case 7
            mytype='string';
        case 8
            mytype='structure';
        case 9
            mytype='double complex';
        case 11
            mytype='object pointer';
        case 12
            mytype='uint16';
        case 13
            mytype='uint32';
        case 14
            mytype='int64';
        case 15
            mytype='uint64';
    end


function strucdesc=new_structure_descriptor()
%NEW_STRUCTURE_DESCRIPTOR - creates a blank structure descriptor record
strucdesc=struct('structstart',0,'name','','predef',0,'ntags',0,...
    'nbytes',0,'tagtable',struct(),'tagnames','','arrtable',[],...
    'structtable',[],'classname','','nsupclasses',0,...
    'supclassnames',0,'supclasstable',[]);

function arrdesc = parse_array_descriptor(fid)
    arrdesc=[];
    arrdesc.arrstart=fread(fid,1,'uint32',0,'b');
    arrdesc.nbytes_el=fread(fid,1,'uint32',0,'b');
    arrdesc.nbytes=fread(fid,1,'uint32',0,'b');
    arrdesc.nelements=fread(fid,1,'uint32',0,'b');
    arrdesc.ndims=fread(fid,1,'uint32',0,'b');
    stuff=fread(fid,2,'uint32',0,'b');
    arrdesc.nmax=fread(fid,1,'uint32',0,'b');
    arrdesc.dims=fread(fid,arrdesc.nmax,'uint32',0,'b')';


function strucdesc = read_structure_descriptor(fid,varargin)
% READ_STRUCTURE_DESCRIPTOR - get structure descriptor record from IDL save
% file stream
%
% C. Pelizzari, October 2013
%

strucdesc=new_structure_descriptor; % initialize structure fields

% read start code?  default no
if nargin > 1 && varargin{1},
    strucdesc.structstart=fread(fid,1,'uint32',0,'b');
end
verbose=0;
% first thing is the structure name (not the variable name, but the
% structure type definition name.  we already know the variable name)
strlen=fread(fid,1,'uint32',0,'b');
strucdesc.name=deblank(char(fread(fid,4*ceil(strlen/4),'char')'));
strucdesc.predef=fread(fid,1,'uint32',0,'b'); % predef - we don't handle it
strucdesc.ntags=fread(fid,1,'uint32',0,'b'); % ntags - # of fields in struct
nbytes=fread(fid,1,'uint32',0,'b'); % this is not used but have to read it
% tagtable has a descriptive entry for each tag (field)
strucdesc.tagtable=struct('offset',[],'typecode',[],'tagflags',[],'name',[]);
for n = 1:strucdesc.ntags
    myoff=fread(fid,1,'uint32',0,'b'); % offset - not used
    mycode=fread(fid,1,'uint32',0,'b'); % type code - what kind of data
    myflags=fread(fid,1,'uint32',0,'b'); % flags - array, structure, etc
    strucdesc.tagtable(n).offset=myoff;
    strucdesc.tagtable(n).typecode=mycode;
    strucdesc.tagtable(n).tagflags=myflags;
end
% next we get all the field names.  put them into the tabtable for
% convenience.  Note we always read a multiple of 4 bytes since the whole
% file structure is organized on 4-byte boundaries.
for n=1:strucdesc.ntags
    strlen=fread(fid,1,'uint32',0,'b');
    strucdesc.tagtable(n).name=...
        deblank(char(fread(fid,4*ceil(strlen/4),'char')'));
end
% see how many arrays and structures there are - will have to process them
myflags=vertcat(strucdesc.tagtable(:).tagflags);
arrflag=hex2dec('04'); % flag for an array
arrmask=bitand(myflags,repmat(arrflag,strucdesc.ntags,1)) > 0;
structflag=hex2dec('20'); % flag for a structure
structmask=bitand(myflags,repmat(structflag,strucdesc.ntags,1)) > 0;
numarrays=numel(find(arrmask));
numstructs=numel(find(structmask));

% read in descriptors for the arrays.  Note that if there are structure
% fields, each of them will also have an array descriptor since structures
% are always contained in arrays, even if they are 1x1.
for n=1:numarrays
       arrdesc =  parse_array_descriptor(fid);
       if n==1, 
           strucdesc.arrtable=arrdesc; 
       else
           strucdesc.arrtable(n)=arrdesc;
       end
end
% read in descriptors for the structures
for n=1:numstructs
       sdesc =  read_structure_descriptor(fid,1);
       if n==1, 
           strucdesc.structtable=sdesc; 
       else
           strucdesc.structtable(n)=sdesc;
       end
end
if verbose
    strucdesc
    for n=1:numarrays
        strucdesc.arrtable(n)
    end
end

function thevar = read_idl_structure_new( fid, strucdesc,varargin )
%READ_IDL_STRUCTURE_NEW - read IDL structure data from open file, based on
% information in structure descriptor.
%
% C. Pelizzari Oct 2013

% structure data is preceded by the startcode, a 32-bit integer "7".
if nargin>2 && varargin{1}, 
    startcode=fread(fid,1,'uint32',0,'b');
end
% do we need to convert all tagnames to lower case? default no
dolower=0;
if nargin > 3, dolower=varargin{2}; end

% our output structure
thevar=struct;
ntags=numel(strucdesc.tagtable);  % number of fields (tags)
myflags=vertcat(strucdesc.tagtable(:).tagflags); % flags - array, structure

% find out if there are any tags which are arrays or structures
arrflag=hex2dec('04');  % this marks an array
structflag=hex2dec('20'); % this marks a structure, which will probably 
                            % also be marked as an array
arrmask=bitand(myflags,repmat(arrflag,strucdesc.ntags,1)) > 0;
numarrays=numel(find(arrmask));
structmask=bitand(myflags,repmat(structflag,strucdesc.ntags,1)) > 0;
numstructs=numel(find(structmask));

narr=0; % which of the arrays in our table are we processing
nst=0;  % ditto for structures
readstart=0;
for n=1:ntags
    if structmask(n),
        nst=nst+1;
        % skip the array table entry corresponding to this -
        % structures also get flagged as arrays, which we will ignore
        if arrmask(n),narr=narr+1;end
        % nested structures don't have a startcode, just read the data
        thisfield=read_idl_structure_new(fid,strucdesc.structtable(nst),readstart,dolower);
    elseif arrmask(n),
        narr=narr+1;
        thisfield=read_idl_array(fid,strucdesc.arrtable(narr),...
            strucdesc.tagtable(n).typecode,dolower,readstart);
    else
        thisfield=read_idl_scalar(fid,strucdesc.tagtable(n).typecode,0);
        
    end
    % put data into the appropriate field in our output structure
    name=strucdesc.tagtable(n).name;
    if dolower, name=lower(name);end
    thevar.(name)=thisfield;
end


function [ thevar ] = read_idl_array( fid,arrdesc,typecode,varargin )
%READ_IDL_ARRAY - read in array from save file input stream based on array
% descriptor
%
% C. Pelizzari October 2013

    % convert name to lowercase? default no
     dolower=0;
     if nargin > 3, dolower=varargin{1}; end
     readstart=1;
     if nargin > 4, readstart=varargin{2}; end
     
     thevar=[]; % our output array
     mytype=idl_element_type(typecode); % what kind of data is it
     nelements=arrdesc.nelements; % how many of them
     ndims=arrdesc.ndims; % dimensionality of the array
     dims=arrdesc.dims; % vector of array dimensions
     if readstart, startcode=fread(fid,1,'uint32',0,'b'); end % skip the startcode
     switch typecode
        case 1
            lenagain=fread(fid,1,'uint32',0,'b');
            thevar=cast(fread(fid,lenagain,'uint8',0,'b'),mytype);
            leftover=4*ceil(lenagain/4)-lenagain;
            if leftover, fseek(fid,leftover,0); end % move to word boundary
        case {2, 3}
            thevar=cast(fread(fid,nelements,'int32',0,'b'),mytype);
        case 4
            thevar=cast(fread(fid,nelements,'float32',0,'b'),mytype);    
        case 5
            thevar=cast(fread(fid,nelements,'float64',0,'b'),mytype);
        case 6
            thevar=fread(fid,2*nelements,'float32',0,'b');
            thevar=reshape(thevar,nelements,2);
            thevar=complex(thevar(:,1),thevar(:,2));
        case 8  % structure - next thing in the file is the descriptor
            strucdesc = read_structure_descriptor(fid,0);
            % now read what the descriptor says
            thevar=read_idl_structure_new(fid,strucdesc,1,dolower);            
        case 9
            thevar=fread(fid,2*nelements,'float64',0,'b');  
            thevar=reshape(thevar,nelements,2);
            thevar=complex(thevar(:,1),thevar(:,2));
        case {12, 13}
            thevar=cast(fread(fid,nelements,'uint32',0,'b'),mytype);
        case 14
            thevar=cast(fread(fid,nelements,'int64',0,'b'),mytype);
        case 15
            thevar=cast(fread(fid,nelements,'uint64',0,'b'),mytype);
         otherwise
             return

     end
     %whos thevar
     %dims
    thevar=reshape(thevar,dims(1:max([2 ndims])));



function thevar = read_idl_scalar( fid,typecode,varargin )
% READ_IDL_SCALAR - reads a scalar variable from IDL save file stream
%
% C. Pelizzari, October 2013
%
    ifstart=1;  % read a start code first? default=yes
    if nargin > 2, ifstart=varargin{1};end % override default
    
    thevar=[];
    mytype=idl_element_type(typecode);  % what kind of variable?

    if ifstart, startcode=fread(fid,1,'uint32',0,'b');end

    switch typecode
        case 1  % byte data
            thevar=cast(fread(fid,1,'uint8',0,'b'),mytype);
            fseek(fid,3,0); % align on next word boundary
        case {2, 3}  % integers: 16 or 32 bit, saved as 32 bit
            thevar=cast(fread(fid,1,'int32',0,'b'),mytype);
        case 4  % float
            thevar=cast(fread(fid,1,'float32',0,'b'),mytype);
        case 5  % double
            thevar=cast(fread(fid,1,'float64',0,'b'),mytype);
        case 6 % single complex
            thevar=fread(fid,2,'float32',0,'b');
            thevar=complex(thevar(1),thevar(2));
        case 7  % string
            strlen=fread(fid,1,'uint32',0,'b');
            strlen=fread(fid,1,'uint32',0,'b');
            thevar=strtrim(char(fread(fid,4*ceil(strlen/4),'char')')); 
        case 9  % double complex
            thevar=fread(fid,2,'float64',0,'b');
            thevar=complex(thevar(1),thevar(2));
        case {12, 13}  % unsigned ints 16 and 32 bit - saved as 32
            thevar=cast(fread(fid,1,'uint32',0,'b'),mytype);
        case 14 % long int
            thevar=cast(fread(fid,1,'int64',0,'b'),mytype);
        case 15 % long unsigned int
            thevar=cast(fread(fid,1,'uint64',0,'b'),mytype);                    
        otherwise


    end
