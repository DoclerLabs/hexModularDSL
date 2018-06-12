package;

import com.hello.*;
import com.bye.*;

/**
 * ...
 * @author Francis Bourre
 */
class Main
{
    static public function main() : Void
    {
		var assembler = new hex.runtime.ApplicationAssembler();
		
		hex.compiletime.flow.modular.FlowCompiler.compile( assembler, 
			'hello.flow' ).then(
			function( code ) 
			{
				code.execute();
				trace( code.locator.hello.sayHello( 'Francis' ) ); 
			}
		);
		
		hex.compiletime.flow.modular.FlowCompiler.compile( assembler,
			'bye.flow'  ).then(
			function( code ) 
			{
				code.execute();
				trace( code.locator.bye.sayBye( 'Mr Bourre' ) ); 
			}
		);
	}
}