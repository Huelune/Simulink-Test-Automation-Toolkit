function digest = st_hash_value(value)
%ST_HASH_VALUE Return a stable SHA-256 digest for text or JSON data.

if ischar(value) || (isstring(value) && isscalar(value))
    text = char(string(value));
else
    text = jsonencode(value);
end

md = java.security.MessageDigest.getInstance('SHA-256');
bytes = unicode2native(text, 'UTF-8');
md.update(typecast(uint8(bytes), 'int8'));
raw = typecast(int8(md.digest()), 'uint8');
digest = lower(reshape(dec2hex(raw, 2).', 1, []));
end
