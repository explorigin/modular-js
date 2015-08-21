require(['HxOverrides', 'bind_stub'], function(HxOverrides) {
    self['$iterator'] = function $iterator(o) {
        if( o instanceof Array ) {
            return function() {
                return HxOverrides.iter(o);
            };
        }
        return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator;
    }
});
