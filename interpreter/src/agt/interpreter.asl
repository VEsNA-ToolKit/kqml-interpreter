//* VEsNA Framework
//* KQML-INTERPRETER

// To use this interpreter add this line to your agent:
//
//  > { include( "interpreter.asl" ) }
//
// Your agent should have two beliefs:
//  - instrumentation( true|false ).
//  - interpreter_class( "[Package.]YourInterpreterClass" ).
//
// Your agent should also implement the following triggering events to manage messages:
//  > +user_msg( Msg ) <- for messages sent broadcast on the chat, without a recipient
//  > +user_msg( Recipients, Msg ) <- for messages sent with a recipient in the chat
// 
// Your Interpreter class should implement the Interpreter interface.
// The agent has access to this methods:
//  - generate_property( Sentence, Property ) <- takes a sentence and returns a logical property in Property
//  - generate_sentence( Performative, Literal, Sentence ) <- it takes the kqml performative and the kqml literal sent and returns a string sentence in Sentence
//  - classify_performative( Sentence, Performative ) <- it classifies the performative of sentence Sentence in Performative
//
// An example triggering event for an interpreter agent is:
// > +user_msg( Msg )
// >      :   true
// >      <-  classify_performative( Msg, Performative );
// >          generate_property( Msg, Belief );
// >          .broadcast( Performative, Belief ). 

!init_interpreter.

// Error if no instrumentation or interpreter_class provided
+!init_interpreter
    :   ( not instrumentation( _ ) | not interpreter_class( _ ) ) & .my_name( Me )
    <-  .print("You need these two beliefs:");
        .print(" - instrumentation( true | false ).");
        .print("   If true the interpreter will instrument the other agents;");
        .print(" - interpreter_class( \"MyInterpreterClass\" ).");
        .print("   The value is the name of the class to use as interpreter that should implement the Interpreter interface.");
        .kill_agent( Me ).


// Initialize the interpreter in case the instrumentation is activated.
+!init_interpreter
    :   instrumentation( true ) & interpreter_class( InterpreterClass )
    <-  makeArtifact( chat, "interpreter.ChatArtifact", [], ChatArtId );
        focus( ChatArtId );
        !instrument_all;
        ?literals( Literals );
        ?beliefs( Beliefs );
        ?plans( Plans );
        .concat( Literals, Beliefs, Plans, AllLiterals );
        makeArtifact( interpreter, InterpreterClass, [ AllLiterals ], IntArtId );
        focus( IntArtId );
        ?running( Condition );
        if ( not Condition ){
            .print("Intepreter initialization failed. Aborting...");
            .all_names( Names );
            for ( .member( Name, Names ) ) {
                .kill_agent( Name );
            }
        }.

// Initialize the interpreter without instrumentation
+!init_interpreter
    :   instrumentation( false ) & interpreter_class( InterpreterClass )
    <-  makeArtifact( chat, "interpreter.ChatArtifact", [], ChatArtId );
        focus( ChatArtId );
        makeArtifact( interpreter, InterpreterClass, [], IntArtId );
        focus( IntArtId ). 


// ** INSTRUMENTATION ** //

// This plan instruments all the agents and waits for all the literals
// from the agents.
@atomic
+!instrument_all
    <-  .all_names( Agents );
        .my_name( Me );
        .length( Agents, N );
        .broadcast( tell, interpreter( Me ) );
        .plan_label( ListPlans, list_plans );
        .plan_label( ProvideLiterals, provide_literals );
        .broadcast( tellHow, ListPlans );
        .broadcast( tellHow, ProvideLiterals );
        .wait( 250 );
        .broadcast( achieve, provide_literals );
        while( .count( literals( _ ), RecvN ) & RecvN < N - 1 ){
            .wait( 500 );
        };
        .broadcast( tellHow, "+_ : interpreter( Interpreter ) <- interpreter.list_beliefs( Beliefs ); .send( Interpreter, tell, beliefs( Beliefs ) ).");
        .broadcast( tellHow, "+!kqml_received( Agent, _, _, _ ) <- .send( Agent, tell, error_message ).").

// This plan is broadcasted to all agents to enumerate the available plans
@list_plans
+!list_plans
    :   interpreter( Intepreter )
    <-  interpreter.list_plans( Plans );
        .concat( "These is what you can do, describe to me your functions using a dotted list. These are your plans: ", Plans, PromptString );
        .send( Name, tell, describe( PromptString ) ).

@provide_literals
+!provide_literals
    :   interpreter( Interpreter )
    <-  .my_name( Me );
        interpreter.list_plans( Plans );
        interpreter.list_beliefs( Beliefs );
        interpreter.list_useful_literals( Literals );
        .send( Interpreter, tell, plans( Plans ) );
        .send( Interpreter, tell, beliefs ( Beliefs ) );
        .send( Interpreter, tell, literals( Literals ) ).

+!kqml_received( Sender, tell, beliefs( Beliefs ), _ )
    :   beliefs( _ )[ source( Sender ) ]
    <-  -+beliefs( Beliefs )[ source( Sender ) ];
        update_embeddings( Beliefs ).

+!kqml_received( Sender, tell, beliefs( Beliefs ), _ )
    <-  -+beliefs( Beliefs )[ source( Sender ) ].

+!kqml_received( Sender, tell, plans( Plans ), _ )
    :   plans( _ )[ source( Sender ) ]
    <-  -+plans( Plans )[ source( Sender ) ];
        update_embeddings( Plans ).

+!kqml_received( Sender, tell, plans( Plans ), _ )
    <-  -+plans( Plans )[ source( Sender ) ].

+!kqml_received( Sender, tell, literals( Literals ), _ )
    :   literals( _ )[ source( Sender ) ]
    <-  -+literals( Literals )[ source( Sender ) ];
        update_embeddings( Literals ).

+!kqml_received( Sender, tell, literals( Literals ), _ )
    <-  -+literals( Literals )[ source( Sender ) ].

// Each message received from the interpreter agent
// - is sent to the interpreter artifact to generate a sentence;
// - is shown in the chat.
+!kqml_received( Sender, Performative, Msg, _ )
    <-  .print("Received ", Msg, " from ", Sender );
        generate_sentence( Performative, Msg, Sentence );
        msg( Sender, Sentence ).