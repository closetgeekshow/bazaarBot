package com.leveluplabs.bazaarbot;
import haxe.io.Path;
import haxe.Json;
import hscript.Interp;
import hscript.Parser;
import openfl.Assets;

/**
 * ...
 * @author 
 */
class AgentLogic
{
	var script:String = "";
	var source:String;
	var root:AgentLogicNode;
	
	private var init:Bool = false;
	
	public function new(data:Dynamic) 
	{
		if (Std.is(data, String)) {
			script = data;
		}else{
			source = Json.stringify(data);
			root = new AgentLogicNode(data);
		}
	}
		
	public function get_production(commodity_:String):Float {
		return 0;
		/*
		if (curr_node == null) {
			return get_production(commodity_, root);
		}else {
			if (!curr_node.isLeaf) {
				var a:Float = get_production(commodity_, curr_node.node_true);
				var b:Float = get_production(commodity_, curr_node.node_false);
				return a + b;
			}else {
				var amount:Float = 0;
				for (act in curr_node.actions) {
					for (i in 0...act.targets.length) {
						switch(act.action) {
							case "produce":								
								if (act.targets[i] == commodity_) {
									amount += act.chances[i] * act.amounts[i];
								}
								break;
							case "transform":
								var amt:Float = act.amounts[i];
								if (amt == -1) { amt = 1;}			//can be misleading
								if (act.results[i] == commodity_) {
									amount += act.chances[i] * amt * act.efficiency[i];
								}
								break;
						}						
					}
				}
				return amount;
			}
		}*/
	}
	
	
	/**
	 * Perform this logic on the given agent
	 * @param	agent
	 */
	
	public function perform(agent:Agent,bazaar:BazaarBot):Void {
		if(script == ""){
			_perform(root, agent);
		}else {
			_perform_script(script, agent, bazaar);
		}
	}
	
	private function _perform_script(script:String, agent:Agent, bazaar:BazaarBot):Void {
		var parser = new Parser();
		var ast = parser.parseString(script);
		var interp = new Interp();
		
		var vars:Map<String,Dynamic> = 
		[
		 "agent" => agent, 
		 "query_inventory" => agent.query_inventory,
		 "produce" => _produce,
		 "consume" => _consume,
		 "inventory_is_full" => agent.get_inventory_space,
		 "make_room_for" => 
			function(a:Agent, c:String="food", amt:Float = 1.0):Void { 
				var to_drop:String = bazaar.get_cheapest_commodity(10,c);
				if (to_drop != "") {_consume(a, to_drop, amt);}
			}
		 ];
		 
		interp.variables = vars;			
	}
	
	private function _produce(agent:Agent, commodity:String, amount:Float, chance:Float=1.0):Void {
		if (chance >= 1.0 || Math.random() < chance) {
			agent.change_inventory(commodity, amount);
		}
	}
	
	private function _consume(agent:Agent, commodity:String, amount:Float, chance:Float=1.0):Void {
		if (chance >= 1.0 || Math.random() < chance) {
			if (commodity == "money") {
				agent.money -= amount;
			}else{
				agent.change_inventory(commodity, -amount);
			}
		}
	}	
	
	/**
	 * Recursively steps through the current node and does the given action for the given agent
	 * @param	curr_node
	 * @param	agent
	 */
	
	private function _perform(curr_node:AgentLogicNode,agent:Agent):Void{
		
		if(!curr_node.isLeaf){								//If not a leaf node
			if (_evaluate(curr_node, agent)) {				//Test the conditions
				if(curr_node.node_true != null){
					_perform(curr_node.node_true, agent);	//Branch to "if_true" node
				}
			}else {
				if(curr_node.node_false != null){
					_perform(curr_node.node_false, agent);	//Branch to "if_false" node
				}
			}
		}else{												//Do the actions
			var act:AgentLogicAction;
			for (act in curr_node.actions) {				
				var i:Int;
				for (i in 0...act.targets.length) {
					var amount:Float  = act.amounts[i];
					var target:String = act.targets[i];
					var chance:Float  = act.chances[i];					
					
					//Roll to see if this happens
					if (chance >= 1.0 || Math.random() < chance) {
						
						var curr_amount:Float = agent.query_inventory(target);
						
						if (amount == -1) {	//-1 means "match my total value"
							amount = curr_amount;
						}
								
						switch(act.action) {
							case "produce":
								agent.change_inventory(target, amount);		//produce some stuff
							case "consume":
								agent.change_inventory(target, -amount);	//consume some stuff
							case "transform":			
								var amount_target:Float = amount;
								
								//exchange rate between A -> B								
								var amount_product:Float = amount * act.efficiency[i]; 
								var result:String = act.results[i];						
								
								agent.change_inventory(target, -amount_target);	//consume this much of A
								agent.change_inventory(result, amount_product); //produce this much of B								
						}
					}
				}					
				
			}
		}
	}
	
	private function _evaluate(curr_node:AgentLogicNode, agent:Agent):Bool {
		//Fail on the first condition that is false
		for (c in curr_node.conditions) {
			switch(c.condition) {
				case "has":	//Do you have something?
					var str:String;
					var has:Bool = false;
					for (str in curr_node.params) {		//look at all the things
						var amount:Float = agent.query_inventory(str);	//count em
						if (amount > 0) {
							has = true;					//have it or not
						}						
						if (c.negated) {					//looking for NO-has
							if (has) { return false;}
						}else {								//looking for YES-has
							if (!has) { return false;}
						}	
					}				
					break;
			}
		}
		return true;
	}
	
}