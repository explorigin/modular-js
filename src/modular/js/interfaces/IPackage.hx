package modular.js.interfaces;

interface IPackage {
    var name:String;
    var code:String;
    var members: haxe.ds.StringMap<IKlass>;
}
