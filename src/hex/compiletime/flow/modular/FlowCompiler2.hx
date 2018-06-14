package hex.compiletime.flow.modular;

import hex.core.IApplicationAssembler;

#if macro
import haxe.macro.Expr;

import hex.compiletime.CompileTimeApplicationAssembler;
import hex.compiletime.CompileTimeParser;
import hex.compiletime.ICompileTimeApplicationAssembler;
import hex.compiletime.basic.CompileTimeApplicationContext;
import hex.compiletime.basic.StaticCompileTimeContextFactory;
import hex.compiletime.flow.AbstractExprParser;
import hex.compiletime.flow.DSLReader;
import hex.compiletime.flow.FlowAssemblingExceptionReporter;
import hex.compiletime.flow.parser.ExpressionParser;
import hex.compiletime.util.ClassImportHelper;
import hex.compiletime.util.ContextBuilder;
import hex.core.ContextTypeList;
import hex.core.VariableExpression;
import hex.log.LogManager;
import hex.log.MacroLoggerContext;
import hex.parser.AbstractParserCollection;
import hex.preprocess.ConditionalVariablesChecker;
import hex.preprocess.flow.MacroConditionalVariablesProcessor;
import hex.util.MacroUtil;
import hex.vo.ConstructorVO;

using Lambda;
using hex.util.LambdaUtil;
using tink.MacroApi;
#end

/**
 * ...
 * @author Francis Bourre
 */
class FlowCompiler2 
{
	#if macro
	public static var ParserCollectionConstructor : VariableExpression
					->String
					->hex.preprocess.RuntimeParam
					->String
					->AbstractParserCollection<AbstractExprParser<hex.compiletime.basic.BuildRequest>>
					= ParserCollection.new;
					
	public static var _m = new Map<String, UInt>();
					
	@:allow( hex.compiletime.flow.parser )
	public static function _readFile(	fileName 						: String,
										?applicationContextName 		: String,
										?preprocessingVariables 		: Expr,
										?conditionalVariables 			: Expr,
										?applicationAssemblerExpression : Expr ) : Expr
	{
		LogManager.context 				= new MacroLoggerContext();
		
		//TODO refactor this disgusting hack
		var split = fileName.split('#');
		var fileName = split[0];
		var exportFileName = split.length > 1 ? split[1] : '';
		
		
		var conditionalVariablesMap 	= MacroConditionalVariablesProcessor.parse( conditionalVariables );
		var conditionalVariablesChecker = new ConditionalVariablesChecker( conditionalVariablesMap );
		
		var reader						= new DSLReader();
		var document 					= reader.read( fileName, preprocessingVariables, conditionalVariablesChecker );
	
		var assembler 					= new CompileTimeApplicationAssembler();
		var assemblerExpression			= { name: '', expression: applicationAssemblerExpression };
		var parser 						= new CompileTimeParser( ParserCollectionConstructor( assemblerExpression, fileName, reader.getRuntimeParam(), exportFileName ) );

		ContextBuilder.onContextTyping( function ( td : TypeDefinition ) { FlowCompiler2._register( exportFileName == '' ? td.name : exportFileName, [td.pack.join('.')]); } );
		
		parser.setImportHelper( new ClassImportHelper() );
		parser.setExceptionReporter( new FlowAssemblingExceptionReporter() );
		parser.parse( assembler, document, StaticCompileTimeContextFactory, CompileTimeApplicationContext, applicationContextName );

		return assembler.getMainExpression();
	}
	
	static function _register( libName: String, values: Array<String> )
	{
			function formatMatch ( s: String )
			{
				var m = s.split('_').join('_$').split('.').join('_');
				return ~/_[A-Z]/.match(m) ? m : m += '_';
			}
			
			var pattern = values
				.map( formatMatch )
				.join(',');

haxe.macro.Context.warning( 'Modular: $libName=$pattern', haxe.macro.Context.currentPos() );

			MySplit.register( '$libName=$pattern' );
	}
	
	public static function getModularData( libName: String, values: Array<String> ) : { libName: String, module: String, bridge: String }
	{
		function formatMatch ( s: String )
		{
			var m = s.split('_').join('_$').split('.').join('_');
			return ~/_[A-Z]/.match(m) ? m : m += '_';
		}
		
		var pattern = values
			.map( formatMatch )
			.join(',');

		var module = '$libName=$pattern';
		var bridge = '${libName}__BRIDGE__';
		
		return { libName: libName, module: module, bridge: bridge };
	}
	#end

	macro public static function compile( 	assemblerExpr 			: Expr, 
											fileName 				: String,
											?applicationContextName : String,
											?preprocessingVariables : Expr, 
											?conditionalVariables 	: Expr,
											?exportFileName			: String = ''	) : Expr
	{
		if ( applicationContextName != null && !hex.core.ApplicationContextUtil.isValidName( applicationContextName ) ) 
		{
			haxe.macro.Context.error( 'Invalid application context name.\n Name should be alphanumeric (underscore is allowed).\n First chararcter should not be a number.', haxe.macro.Context.currentPos() );
		}
		
		return FlowCompiler2._readFile( fileName + (exportFileName==''?'':'#'+exportFileName) , applicationContextName, preprocessingVariables, conditionalVariables, assemblerExpr );
	}
	
	macro public static function extend<T>( assemblerExpr 			: Expr, 
											applicationContextName : String,
											fileName 				: String, 
											?preprocessingVariables : Expr, 
											?conditionalVariables 	: Expr ) : ExprOf<T>
	{
		return FlowCompiler2._readFile( fileName, applicationContextName, preprocessingVariables, conditionalVariables, assemblerExpr );
	}
}

#if macro
class ParserCollection extends AbstractParserCollection<AbstractExprParser<hex.compiletime.basic.BuildRequest>>
{
	var _assemblerExpression 	: VariableExpression;
	var _fileName 				: String;
	var _runtimeParam 			: hex.preprocess.RuntimeParam;
	var _exportFileName 		: String;
	
	public function new( assemblerExpression : VariableExpression, fileName : String, runtimeParam : hex.preprocess.RuntimeParam, exportFileName : String ) 
	{
		this._assemblerExpression 	= assemblerExpression;
		this._fileName 				= fileName;
		this._runtimeParam 			= runtimeParam;
		this._exportFileName 		= exportFileName;
		
		super();
	}
	
	override function _buildParserList() : Void
	{
		this._parserCollection.push( new StaticContextParser( this._assemblerExpression ) );
		this._parserCollection.push( new hex.compiletime.flow.parser.RuntimeParameterParser( this._runtimeParam ) );
		this._parserCollection.push( new ImportContextParser( hex.compiletime.flow.parser.FlowExpressionParser.parser ) );
		this._parserCollection.push( new hex.compiletime.flow.parser.ObjectParser( hex.compiletime.flow.parser.FlowExpressionParser.parser, this._runtimeParam ) );
		this._parserCollection.push( new ModularLauncher( this._assemblerExpression, this._fileName, this._runtimeParam, this._exportFileName ) );
	}
}

class ImportContextParser extends AbstractExprParser<hex.compiletime.basic.BuildRequest>
{
	var _parser 			: ExpressionParser;
	
	public function new( parser : ExpressionParser ) 
	{
		super();
		this._parser = parser;
	}
	
	override public function parse() : Void 
	{
		this.transformContextData
		( 
			function( exprs :Array<Expr> ) 
			{
				var transformation = exprs.transformAndPartition( _transform );
				transformation.is.map( _parseImport );
				return transformation.isNot;
			}
		);
	}
	
	function _transform( e : Expr ) : Transformation<Expr, hex.compiletime.flow.parser.ContextImport>
	{
		return switch ( e )
		{
			case macro $i{ident} = new Context( $a{params} ):
				Transformed( {
								id:ident, 
								isPublic: false,
								fileName: 	switch( params[ 0 ].expr )
											{
												case EConst(CString(s)): s; 
												case _: ''; 
											}, 
								arg: params.length>1 ? this._parser.parseArgument( this._parser, ident, params[ 1 ] ): null,
								pos:e.pos 
							});
							
			case macro @public $i{ident} = new Context( $a{params} ):
				Transformed( {
								id:ident, 
								isPublic: true,
								fileName: 	switch( params[ 0 ].expr )
											{
												case EConst(CString(s)): s; 
												case _: ''; 
											}, 
								arg: params.length>1 ? this._parser.parseArgument( this._parser, ident, params[ 1 ] ): null,
								pos:e.pos 
								});
			
			case _: Original( e );
		}
	}
	
	function _parseImport( i : hex.compiletime.flow.parser.ContextImport )
	{
		var className = this._applicationContextName + '_' + i.id;
		var e = this._getCompiler( i.fileName)( i.fileName, className, null, null, macro this._applicationAssembler );
		ContextBuilder.forceGeneration( className );
		
		var args = [ { className: 'hex.context.' + className/*this._getClassName( e )*/, expr: e, arg: i.arg } ];
		var vo = new ConstructorVO( i.id, ContextTypeList.CONTEXT, args );
		vo.isPublic = true;
		vo.filePosition = i.pos;
		this._builder.build( OBJECT( vo ) );
	}
	
	function _getClassName( expr : Expr ) : String
	{
		var className = '';
		
		function findClassName( e )
			switch( e.expr )
			{
				case ENew( t, params ): className = /*'I' +*/ t.pack.join('.') + '.' + t.name;
				case _: 				ExprTools.iter( e, findClassName );
			}
		
		ExprTools.iter( expr, findClassName );
		return className;
	}
	
	function _getCompiler( url : String )
	{
		//TODO remove hardcoded compilers assigned to extensions
		switch( url.split('.').pop() )
		{
			case 'xml':
				return hex.compiletime.xml.BasicStaticXmlCompiler._readFile;
				
			case 'flow':
				return FlowCompiler2._readFile;
				
			case ext:
				trace( ext );
				
		}
		
		return null;
	}
}

class StaticContextParser extends AbstractExprParser<hex.compiletime.basic.BuildRequest>
{
	var _assemblerVariable 	: VariableExpression;

	public function new( assemblerVariable : VariableExpression ) 
	{
		super();
		this._assemblerVariable = assemblerVariable;
	}
	
	override public function parse() : Void
	{
		//Register
		if ( this._applicationContextClass.name == null ) this._applicationContextClass.name = Type.getClassName( hex.runtime.basic.ApplicationContext );
		ContextBuilder.register( this._applicationAssembler.getFactory( this._factoryClass, this.getApplicationContext() ), this._applicationContextClass.name );
		
		//Create runtime applicationAssembler
		if ( this._assemblerVariable.expression == null )
		{
			var applicationAssemblerTypePath = MacroUtil.getTypePath( "hex.runtime.ApplicationAssembler" );
			this._assemblerVariable.expression = macro new $applicationAssemblerTypePath();
		}
		
		//Create runtime applicationContext
		var applicationContextClass = null;
		try
		{
			applicationContextClass = MacroUtil.getPack( this._applicationContextClass.name );
		}
		catch ( error : Dynamic )
		{
			this._exceptionReporter.report( "Type not found '" + this._applicationContextClass.name + "' ", this._applicationContextClass.pos );
		}
		
		//Add expression
		var expr = macro @:mergeBlock { var applicationContext = this._applicationAssembler.getApplicationContext( $v { this._applicationContextName }, $p { applicationContextClass } ); };
		( cast this._applicationAssembler ).addExpression( expr );
	}
}

class ModularLauncher extends AbstractExprParser<hex.compiletime.basic.BuildRequest>
{
	var _assemblerVariable 	: VariableExpression;
	var _fileName 			: String;
	var _runtimeParam 		: hex.preprocess.RuntimeParam;
	//var _exportFileName 	: String;
	
	public function new( assemblerVariable : VariableExpression, fileName : String, runtimeParam : hex.preprocess.RuntimeParam, exportFileName : String = '' ) 
	{
		super();
		
		this._assemblerVariable = assemblerVariable;
		this._fileName 			= fileName;
		this._runtimeParam 		= runtimeParam;
		//this._exportFileName 	= /*exportFileName == '' ?*/ this._applicationContextName /*: exportFileName*/;
	}
	
	override public function parse() : Void
	{
		var assembler : ICompileTimeApplicationAssembler = cast this._applicationAssembler;
		
		//Dispatch CONTEXT_PARSED message
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.CONTEXT_PARSED" );
//		assembler.addExpression( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );

		//Create applicationcontext injector
		assembler.addExpression( macro @:mergeBlock { var __applicationContextInjector = applicationContext.getInjector(); } );

		//Create runtime coreFactory
		assembler.addExpression( macro @:mergeBlock { var coreFactory = applicationContext.getCoreFactory(); } );

		//build
		assembler.buildEverything();

		//
		var assemblerVarExpression = this._assemblerVariable.expression;
		var factory = assembler.getFactory( this._factoryClass, this.getApplicationContext() );
		var builder = ContextBuilder.getInstance( factory );
		var file 	= ContextBuilder.getInstance( factory ).buildFileExecution( this._fileName, assembler.getMainExpression(), this._runtimeParam );

		var contextName = this._applicationContextName;
		var varType = builder.getType();
	
		var className = builder._iteration.definition.name;

		var classExpr;
		
		var applicationContextClassName = this._applicationContextClass.name == null ? 
			Type.getClassName( hex.runtime.basic.ApplicationContext ): 
				this._applicationContextClass.name;
			
		var applicationContextClassPack = MacroUtil.getPack( applicationContextClassName );
		var applicationContextCT		= haxe.macro.TypeTools.toComplexType( haxe.macro.Context.getType( applicationContextClassName ) );

		var contextFQN = this._applicationContextPack.join('.') + '.' + contextName;
		classExpr = macro class $className { public function new( locatorClass, assembler )
		{
			this.locator 				= Type.createInstance( locatorClass, [ assembler ] );
			this.applicationAssembler 	= assembler;
			this.applicationContext 	= this.locator.$contextName;
		}};

		classExpr.pack = builder._iteration.definition.pack;
		
		classExpr.fields.push(
		{
			name: 'locator',
			pos: haxe.macro.Context.currentPos(),
			kind: FVar( varType ),
			access: [ APublic ]
		});
		
		classExpr.fields.push(
		{
			name: 'applicationAssembler',
			pos: haxe.macro.Context.currentPos(),
			kind: FVar( macro:hex.core.IApplicationAssembler ),
			access: [ APublic ]
		});
		
		classExpr.fields.push(
		{
			name: 'applicationContext',
			pos: haxe.macro.Context.currentPos(),
			kind: FVar( applicationContextCT ),
			access: [ APublic ]
		});
		
		var locatorArguments = if ( this._runtimeParam.type != null ) [ { name: 'param', type:_runtimeParam.type } ] else [];

		var locatorBody = this._runtimeParam.type != null ?
			macro this.locator.$file( param ) :
				macro this.locator.$file();

		var className = classExpr.pack.join( '.' ) + '.' + classExpr.name;
		var cls = className.asTypePath();


		classExpr.fields.push(
		{
			name: 'execute',
			pos: haxe.macro.Context.currentPos(),
			kind: FFun( 
			{
				args: locatorArguments,
				ret: macro : Void,
				expr: locatorBody
			}),
			access: [ APublic ]
		});

		//Define Type
		haxe.macro.Context.defineType( classExpr );
var modularCode = FlowCompiler2.getModularData( this._applicationContextName, builder._iteration.definition.pack );
		var typePath = MacroUtil.getTypePath( className );
		
		//Generate module's name
		var module = className.split('_').join('_$').split('.').join('_');
		var mods = module.split('_');
		mods.splice( mods.length -1, 1 );
		module = mods.join( '_' );
		
		
		//
		var m = FlowCompiler2._m;
		if ( !m.exists( this._applicationContextName ) ) m.set( this._applicationContextName, 0 );
		m.set( this._applicationContextName, m.get( this._applicationContextName ) + 1 );

		var factoryClassName = 'Factory' + m.get( this._applicationContextName );
		var factoryExpr = macro class $factoryClassName {
			public static function getCode( assembler )
			{
				var instance = new $typePath( untyped $p { [module] }, assembler );
				return instance;
			}
		};
		factoryExpr.pack = builder._iteration.definition.pack;
		haxe.macro.Context.defineType( factoryExpr );
		
		var factory = factoryExpr.pack.join('_') + '_' +factoryClassName;
		//MySplit.register( factory );
		var bridge2 = macro var f = untyped $i { factory };
		
		var modular = macro 
		{
			@:keep Require.module( $v{modularCode.libName} )
							.then(
							function(id:String) 
							{
								var _ = $v { modularCode.bridge };
								trace( _ );
								$bridge2;
								trace( f );
								var instance = f.getCode( $assemblerVarExpression );
								return instance;
							});
		};
		/*
		return macro {
					@:keep Require.module($v{libName})
						.then(function(id:String) {
							var _ = $v{bridge};
							return id;
						});
				}
*/
		/*var modular = macro 
		{
			@:keep Require.module( $v{ modularCode.libName } )
				.then(function(id:String) {
					var _ = $v { modularCode.bridge };
					var instance = new $typePath( untyped $p { [module] }, $assemblerVarExpression );
					return instance;
				});
		}*/

		assembler.setMainExpression( macro @:mergeBlock $modular  );
	}
	
	
}
#end