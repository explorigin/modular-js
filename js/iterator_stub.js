define(['HxOverrides', 'bind_stub'], function(HxOverrides) {
    return self['$iterator'] = function $iterator(o) {
        if( o instanceof Array ) {
            return function() {
                return HxOverrides.iter(o);
            };
        }
        return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator;
    }
});
