package lse.math.games.builder.model 
{	
	import flash.net.FileReference;
	
	import util.Log;

	/**	  
	 * This class represents a full game-tree in its extensive form. 
	 * </p>It contains:
	 * <ul><li>Reference to the root node and to the first player.</li>
	 * <li>Functions to add players, nodes and information sets to the game tree, as well as to access them by id</li>
	 * <li>Functions related to making perfect recall</li>
	 * <li>Functions to get the following tree properties: depth & number of leaves</li>
	 * 
	 * @author Mark Egesdal
	 */
	public class ExtensiveForm extends Game
	{			
		private var _root:Node;
		
		private var lastNodeNumber:int = 0;
		private var lastOrderedNodeNumber:int = 0;
		private var lastOrderedIsetNumber:int = 0;
		
		private var log:Log = Log.instance;
		
		
			
		/** First node of the tree */
		public function get root():Node { return _root; }
		public function set root(value:Node):void { _root = value; }
		
		/** Number of nodes in the tree */
		public function get numNodes():int {
			return root.numNodesInSubtree();
		}
		
		/** Number of information sets in the tree */
		public function get numIsets():int {
			var count:int = 0;
			for (var h:Iset = root.iset; h != null; h = h.nextIset) {
				++count;
			}
			return count;
		}
				
		
		
		/** Clears all the info contained in the tree, creating a new one without player or nodes */
		public function clearTree():void
		{
			_root = null;
			_firstPlayer = null;
			lastNodeNumber = 0;
			lastOrderedIsetNumber = 0;
			lastOrderedNodeNumber = 0;
		}
		
		/** Creates a new player, assigning it as moving next of the last one currently existing in this tree */
		public function newPlayer(name:String):Player {
			return new Player(name, this);
		}
		
		/** Creates a new node assigning it an autoincreasing ID */
		public function createNode():Node {						
			return newNode(getNextNodeNumber());
		}
		
		//Returns an auto-increasing id for labelling the nodes in the tree
		private function getNextNodeNumber():int {			
			return lastNodeNumber++;
		}
		
		// Creates a node with a determinate 'number' (id)
		protected function newNode(number:int):Node {
			return new Node(this, number);
		}
		
		/** 
		 * Assigns nodes and isets ids in pre-order. It should be called after all
		 * actions that might change the tree pre-order representation.
		 */
		public function orderIds():void
		{
			//Reset all iset numbers
			var h:Iset = root.iset;
			while(h!=null)
			{
				h.idx = -1;
				h = h.nextIset;
			}
			
			lastOrderedNodeNumber = 0;
			lastOrderedIsetNumber = 0;
			recOrderIds(_root);
		}
		
		//Recursively adds new idxs to nodes and isets
		private function recOrderIds(node:Node):void
		{
			node.number = lastOrderedNodeNumber++;
			if(node.iset!=null && node.iset.idx == -1) node.iset.idx = lastOrderedIsetNumber++;
			
			var child:Node = node.firstChild;
			while(child!=null) 
			{
				recOrderIds(child);
				child = child.sibling;
			}
		}
		
		/** Searchs for a node with a determinate 'number' (id). If it finds it, it returns it, else it returns null */
		public function getNodeById(number:int):Node
		{
			return recGetNodeById(root, number);
		}
		
		/*
		 * Recursive function that looks for a node with a certain 'number' (id)
		 * Stopping criteria: that the current node has the id we're looking for
		 * Recursive expansion: to all of the node's children
		 *
		 * @return: the current node, if it is the one we're looking for; the found node coming 
		 * from a children return, or null if none of the before apply
		 */
		private function recGetNodeById(node:Node, number:int):Node
		{
			if (node.number == number) {
				return node;
			} 
			
			var child:Node = node.firstChild;
			while (child != null) {
				var rv:Node = recGetNodeById(child, number);
				if (rv != null) {
					return rv;
				}
				child = child.sibling;
			}
			return null;
		}
		
		/**
		 * Adds an Iset to the tree, at the end of the linked list of isets 
		 * (which doesn't directly relate to the spatial location in the tree).
		 * <br>If the Iset was already in the list, it does nothing.
		 * @return (int) The added isets' idx after insertion
		 */
		public function addIset(toAdd:Iset):int
		{
			if (root == null) 
				log.add(Log.ERROR_THROW, "Cannot add isets until root is set");
			
			var h:Iset = root.iset;		
			var idx:int = -1; //index if the iset already exists
			while (true) {
				if (h == toAdd) {
					idx = h.idx;
					log.add(Log.ERROR_HIDDEN, "Pretended to add an iset equal to the one existing with idx "+idx);
					break;
				} else if (h.nextIset == null || h.nextIset.idx>toAdd.idx) {
					break;
				}
				h = h.nextIset;
			}
			if (idx == -1) {
				h.insertAfter(toAdd, false);
			}
			return toAdd.idx;
		}

		/** Searches for an Iset with a determinate id. It returns it if it finds it, else returns null */
		public function getIsetById(iset:int):Iset
		{
			var h:Iset = root.iset;
			while (h != null) {
				if (h.idx == iset) {
					return h;
				}
				h = h.nextIset;
			}
			return null;
		}		

		/**
		 * It rearranges the tree to make sure that every node follows
		 * the principles of perfect recall: that every node in its Iset
		 * comes from the same own move sequence
		 */
		public function makePerfectRecall():void
		{
			//It looks through all isets of the tree, seacrhing for those whose nodes have different move sequences
			for (var h:Iset = _root.iset; h != null; h = h.nextIset) {
				if (!h.hasPerfectRecall())
				{
					//Nodes from the iset are collected
					var nodesInIset:Vector.<Node> = new Vector.<Node>();					
					for (var node:Node = h.firstNode; node != null; node = node.nextInIset) {
						nodesInIset.push(node);						
					}		
					//The Iset is disolved
					h.dissolve();
					//New Isets are formed in groups with same own move sequence
					mergeNodesWithSameOwnMoveSequence(nodesInIset); 
				}				
			}			
		}
		
		//Creates isets for each group of nodes in the vector with the same own move sequence
		private function mergeNodesWithSameOwnMoveSequence(nodesToMerge:Vector.<Node>):void
		{
			while (nodesToMerge.length > 1)
			{
				var base:Node = nodesToMerge.shift();
				var numToCheck:int = nodesToMerge.length;
				for (var i:int = 0; i < numToCheck; ++i) {
					var toMerge:Node = nodesToMerge.shift(); 
					if (base.hasSameOwnMoveSequenceAs(toMerge)) {						
						base.iset.merge(toMerge.iset);
					} else {						
						nodesToMerge.push(toMerge); // add it back to the end
					}
				}
			}			
		}

		/** @return The maximum depth (distance from root to leaf) of the tree */
		public function maxDepth():int
		{
			return recMaxDepth(root);
		}
		
		/*
		* Recursive function that returns the max depth of a node's children
		* Stopping criteria: that the current node is a leaf
		* Recursive expansion: to all of the node's children
		*/
		private function recMaxDepth(node:Node):int
		{
			if (node.isLeaf) {
				return node.depth;
			}
			else
			{
				var max:int = 0;				
				for (var child:Node = node.firstChild; child != null; child = child.sibling)
				{
					var submax:int = recMaxDepth(child);
					if (submax > max) {
						max = submax;
					}					
				}
				return max;
			}
		}
		
		/** @return (int) the number of leaves (nodes without children) of the tree */
		public function numberLeaves():int
		{
			return recNumberLeaves(_root);
		}
	
		/*
		* Recursive function that returns the number of leaves below a determinate node
		* Stopping criteria: that the current node is a leaf
		* Recursive expansion: to all of the node's children
		*/
		protected function recNumberLeaves(node:Node):int
		{			
			if (node.isLeaf) {
				return 1;
			}
			else
			{
				var leafcurrnum:int = 0;
				var y:Node = node.firstChild;
				while (y != null)
				{
					leafcurrnum += recNumberLeaves(y);
					y = y.sibling;
				}
				return leafcurrnum;
			}
		}
			
		/** Save a TXT representation of the tree */
		public function saveTreeTXT():void
		{
			new FileReference().save(printTree(), "treedump.txt");			
		}
		
		private var treeLog:String = "";
		
		//used for debugging
		public function printTree():String
		{
			treeLog = "";
			recPrintTree(root);
			return treeLog;
		}
		
		private function recPrintTree(x:Node):void  // preorder: node, then children
		{
			var indent:String = "";
			for (var i:int = 0; i < x.depth; ++i) {
				indent += "    ";
			}
						
			var y:Node = x.firstChild;
			treeLog += (indent + x.toString() + ((y == null) ? " (leaf)" : ("")) +"\n");
			
			while (y != null)
			{
				recPrintTree(y);
				y = y.sibling;
			}	
		}
		
		public function toString():String
		{
			var numIsets:int = 0;
			var numLevels:int = maxDepth();
			
			for (var h:Iset = root.iset; h != null; h = h.nextIset)
			{
				++numIsets;
			}
			
			return "numIsets: " + numIsets + ", numNodes: " + numNodes + ", numLevels: " + numLevels;
		}
	}
}