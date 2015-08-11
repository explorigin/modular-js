package modular.js.interfaces;

interface IField {
    var name:String;
    var code:String;
    var path:String;
    var isStatic:Bool;
    var dependencies:haxe.ds.StringMap<String>;
    public function getCode():String;
}
