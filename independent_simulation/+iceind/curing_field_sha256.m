function h=curing_field_sha256(file)
%CURING_FIELD_SHA256 Lowercase SHA-256 of a file, via the JDK bundled with MATLAB.
assert(isfile(file),'iceind:CuringField','Missing file: %s',file);
md=java.security.MessageDigest.getInstance('SHA-256');
fid=fopen(file,'rb'); assert(fid>=0,'iceind:CuringField','Cannot open %s',file);
cleanup=onCleanup(@()fclose(fid));
md.update(fread(fid,Inf,'*uint8'));
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
