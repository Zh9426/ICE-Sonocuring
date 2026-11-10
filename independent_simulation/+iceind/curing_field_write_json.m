function curing_field_write_json(file,value)
%CURING_FIELD_WRITE_JSON UTF-8 pretty JSON without overwriting silently.
if isfile(file)
    error('iceind:CuringFieldNoOverwrite', ...
        'Refusing to overwrite existing artifact: %s',file);
end
fid=fopen(file,'w','n','UTF-8');
assert(fid>=0,'iceind:CuringField','Cannot open %s',file);
cleanup=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
