package;

import com.hello.*;
import com.bye.*;
import hex.compiletime.flow.BasicStaticFlowCompiler;
import hex.runtime.ApplicationAssembler;


/**
 * ...
 * @author Francis Bourre
 */
class Main
{
    static public function main() : Void
    {
		
		var assembler = new hex.runtime.ApplicationAssembler();
		
		/*hex.compiletime.flow.modular.FlowCompiler2.compile( assembler, 
			'hello.flow' ).then(
			function( code ) 
			{
				code.execute();
				trace( code.locator.hello.sayHello( 'Francis' ) ); 
			}
		);
		
		hex.compiletime.flow.modular.FlowCompiler2.compile( assembler,
			'bye.flow'  ).then(
			function( code ) 
			{
				code.execute();
				trace( code.locator.bye.sayBye( 'Mr Bourre' ) ); 
			}
		);*/
		
		
		/*var emu = new hex.unittest.runner.ExMachinaUnitCore();
		emu.addListener( new hex.unittest.notifier.BrowserUnitTestNotifier() );
		
		// emu.addListener( new hex.unittest.notifier.ConsoleNotifier( false, true ) );
		// emu.addListener( new TraceNotifier() );
		emu.addTest( Suite );

		emu.run();*/
		
		
		//var code = BasicStaticFlowCompiler.compile( new ApplicationAssembler(), "context/flow/primitives/string.flow"/*, "BasicStaticFlowCompiler_testBuildingString"*/ );
		
		/*var locator = code.locator;
		code.execute();
		
		trace( locator.s );*/
		
		
		Bundle.load( HelloToModular ).then(
			function(_) {
				var hello = new com.hello.HelloToModular();
				trace(hello.sayHello( 'Francis' ));
			}
		);
		
		
		Bundle.load( ByeToModular ).then(
			function(_) {
				var bye = new com.bye.ByeToModular();
				trace(bye.sayBye( 'Mr Bourre' ));
			}
		);
	}
}
/*
class Suite
{
	@Suite( "HexMachina" )
    public var list : Array<Class<Dynamic>> = 
	[ 
		hex.HexCoreSuite,
		hex.HexUnitSuite,
		hex.HexLogSuite,
        hex.HexReflectionSuite,
		hex.HexAnnotationSuite,
		hex.HexInjectSuite,
		hex.HexDslSuite,
		hex.HexCommandSuite
	];
}*/