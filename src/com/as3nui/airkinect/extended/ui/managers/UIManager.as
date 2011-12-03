/**
 *
 * User: Ross
 * Date: 11/19/11
 * Time: 1:02 PM
 */
package com.as3nui.airkinect.extended.ui.managers {
	import com.as3nui.airkinect.extended.ui.components.interfaces.core.IAttractor;
	import com.as3nui.airkinect.extended.ui.components.interfaces.core.ICaptureHost;
	import com.as3nui.airkinect.extended.ui.components.interfaces.core.IUIComponent;
	import com.as3nui.airkinect.extended.ui.events.CursorEvent;
	import com.as3nui.airkinect.extended.ui.objects.Cursor;

	import flash.display.DisplayObject;
	import flash.display.InteractiveObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.utils.Dictionary;

	public class UIManager {
		public static var PARENT_SEARCH_ENABLED:Boolean		= true;

		private static var _instance:UIManager;

		public static function get instance():UIManager {
			if(!_instance) throw new Error("UIManager must be initialized to be used at Singleton");
			return _instance;
		}

		public static function get isInitialized():Boolean {
			return _instance is UIManager;
		}

		public static function init(stage:Stage):void {
			if(_instance) return;
			_instance = new UIManager(stage);
		}

		public static function addCursor(cursor:Cursor):void {
			instance.addCursor(cursor)
		}

		public static function removeCursor(cursor:Cursor):void {
			instance.removeCursor(cursor)
		}
		
		public static function registerComponent(interactiveObject:InteractiveObject):void {
			instance.registerComponent(interactiveObject);
		}

		public static function unregisterComponent(interactiveObject:InteractiveObject):void {
			instance.unregisterComponent(interactiveObject);
		}

		public static function get customObjectFilter():Function {
			return instance.customObjectFilter;
		}

		public static function set customObjectFilter(value:Function):void {
			instance.customObjectFilter = value;
		}

		//----------------------------------
		// Instance
		//----------------------------------
		protected var _components:Vector.<InteractiveObject>;
		protected var _cursors:Vector.<Cursor>;
		protected var _cursorContainer:Sprite;

		protected var _stage:Stage;
		protected var _pulseSprite:Sprite;

		//Reusable Vector 3D Point;
		protected var _inputPoint:Vector3D = new Vector3D();
		protected var _customObjectFilter:Function;
		protected var _targetLookup:Dictionary;

		public function UIManager(stage:Stage) {
			_stage = stage;

			_cursorContainer = new Sprite();
			stage.addChild(_cursorContainer);
			stage.addEventListener(Event.ADDED, onStageChildAdded);
			stage.addEventListener(Event.ENTER_FRAME, onPulse);

			this._cursors = new <Cursor>[];
			this._components = new <InteractiveObject>[];
			this._targetLookup = new Dictionary();
		}

		private function onStageChildAdded(event:Event):void {
			updateCursorContainer();
		}

		private function updateCursorContainer():void {
			if(_stage.contains(_cursorContainer)) _stage.setChildIndex(_cursorContainer, _stage.numChildren-1);
		}

		public function addCursor(cursor:Cursor):void {
			if(this._cursors.indexOf(cursor) >= 0) return;
			this._cursors.push(cursor);
			_cursorContainer.addChild(cursor.icon);
		}

		public function removeCursor(cursor:Cursor):void {
			var cursorIndex:Number = this._cursors.indexOf(cursor);
			if(cursorIndex == -1) return;
			this._cursors.splice(cursorIndex, 1);

			if(!_targetLookup[cursor.source]) _targetLookup[cursor.source] = new Dictionary();
			//Cursor Removed dispatch out for any objects it is over
			if(_targetLookup[cursor.source][cursor.id]) {
				//Convert InputPoint coords into stage coords
				_inputPoint.x = cursor.x * _stage.stageWidth;
				_inputPoint.y = cursor.y * _stage.stageHeight;

				// Interactive Object under the current Input Point
				var cursorPoint:Point = cursor.toPoint();
				cursorPoint.x *= _stage.stageWidth;
				cursorPoint.y *= _stage.stageHeight;
				
				var targetObject:InteractiveObject = getInteractiveObjectUnderPoint(cursorPoint);
				var localPoint:Point = targetObject.globalToLocal(cursorPoint);

				//Dispatch OUT
				(_targetLookup[cursor.source][cursor.id] as InteractiveObject).dispatchEvent(new CursorEvent(CursorEvent.OUT, cursor,  targetObject, localPoint.x,  localPoint.y,  _inputPoint.x,  _inputPoint.y));
			}

			if(_cursorContainer.contains(cursor.icon)) _cursorContainer.removeChild(cursor.icon);
		}

		public function onPulse(event:Event):void {
			for each(var cursor:Cursor in this._cursors){
				if(!cursor.enabled) continue;

				//Convert InputPoint coords into stage coords
				_inputPoint.x = cursor.x * _stage.stageWidth;
				_inputPoint.y = cursor.y * _stage.stageHeight;

				if(cursor.state != Cursor.CAPTURED){
					var xDiff:Number = _inputPoint.x - cursor.icon.x;
					var yDiff:Number = _inputPoint.y - cursor.icon.y;
					cursor.xVelocity = (xDiff * cursor.easing);
					cursor.yVelocity = (yDiff * cursor.easing);

					if(cursor.attractor != null){
						xDiff = cursor.attractor.globalCenter.x - cursor.icon.x;
						yDiff = cursor.attractor.globalCenter.y - cursor.icon.y;

						var xRatio:Number = Math.abs(xDiff / (cursor.attractor.captureWidth/2));
						var yRatio:Number = Math.abs(yDiff / (cursor.attractor.captureHeight/2));
						if(xRatio > 1) xRatio = 1;
						if(yRatio > 1) yRatio = 1;
						xRatio = Math.abs(1 - xRatio);
						yRatio = Math.abs(1 - yRatio);

						cursor.xVelocity = xDiff * (cursor.attractor.minPull + (xRatio * (cursor.attractor.maxPull - cursor.attractor.minPull)));
						cursor.yVelocity = yDiff * (cursor.attractor.minPull + (yRatio * (cursor.attractor.maxPull - cursor.attractor.minPull)));

						if(Math.abs(cursor.xVelocity) <= .1 && Math.abs(cursor.yVelocity) <= .1){
							cursor.xVelocity = 0;
							cursor.yVelocity = 0;

							cursor.icon.x = cursor.attractor.globalCenter.x;
							cursor.icon.y = cursor.attractor.globalCenter.y;
							cursor.attractor.captureHost.capture(cursor);
						}
					}
				}

				cursor.icon.x += cursor.xVelocity;
				cursor.icon.y += cursor.yVelocity;

				// Interactive Object under the current Input Point
				var cursorPoint:Point = cursor.toPoint();
				cursorPoint.x *= _stage.stageWidth;
				cursorPoint.y *= _stage.stageHeight;
				var targetObject:InteractiveObject = getInteractiveObjectUnderPoint(cursorPoint);
				var localPoint:Point = targetObject.globalToLocal(cursorPoint);

				if(!_targetLookup[cursor.source]) _targetLookup[cursor.source] = new Dictionary();

				if(!_targetLookup[cursor.source][cursor.id]) {
					_targetLookup[cursor.source][cursor.id] = targetObject;

					if(targetObject is IAttractor && cursor.attractor == null && cursor.captureHost == null) {
						if(!(targetObject is ICaptureHost && (targetObject as ICaptureHost).hasCursor)) cursor.startAttraction(targetObject as IAttractor);
					}
					//Dispatch OVER
					targetObject.dispatchEvent(new CursorEvent(CursorEvent.OVER, cursor,  targetObject, localPoint.x,  localPoint.y,  _inputPoint.x,  _inputPoint.y));
				}

				var originalTarget:InteractiveObject = _targetLookup[cursor.source][cursor.id] as InteractiveObject;
				if(originalTarget != targetObject){
					if(originalTarget is IAttractor) cursor.stopAttraction();
					if(originalTarget is ICaptureHost && (originalTarget as ICaptureHost).hasCursor) (originalTarget as ICaptureHost).release(cursor);
					
					//Dispatch OUT
					(originalTarget as InteractiveObject).dispatchEvent(new CursorEvent(CursorEvent.OUT, cursor,  targetObject, localPoint.x,  localPoint.y,  _inputPoint.x,  _inputPoint.y));

					//Dispatch OVER
					_targetLookup[cursor.source][cursor.id] = targetObject;
					targetObject.dispatchEvent(new CursorEvent(CursorEvent.OVER, cursor,  targetObject, localPoint.x,  localPoint.y,  _inputPoint.x,  _inputPoint.y));
					if(targetObject is IAttractor && cursor.attractor == null && cursor.captureHost == null) {
						if(!(targetObject is ICaptureHost && (targetObject as ICaptureHost).hasCursor)) cursor.startAttraction(targetObject as IAttractor);
					}
				}

				//Dispatch MOVE
				targetObject.dispatchEvent(new CursorEvent(CursorEvent.MOVE, cursor,  targetObject, localPoint.x,  localPoint.y,  _inputPoint.x,  _inputPoint.y));
			}
		}

		public function registerComponent(interactiveObject:InteractiveObject):void {
			if(_components.indexOf(interactiveObject) >= 0) return;
			this._components.push(interactiveObject);
		}

		public function unregisterComponent(interactiveObject:InteractiveObject):void {
			if(_components.indexOf(interactiveObject) == -1) return;
			var componentIndex:Number = this._components.indexOf(interactiveObject);
			this._cursors.splice(componentIndex, 1);
		}

		//----------------------------------
		// Utility Functions
		//----------------------------------
		protected function getInteractiveObjectUnderPoint(point:Point):InteractiveObject {
			//Allows users to supply custom filters
			if(_customObjectFilter != null) return _customObjectFilter.apply(this, [point]);

			var targets:Array =  _stage.getObjectsUnderPoint(point);
			var item:DisplayObject;

			while(targets.length > 0) {
				item = targets.pop() as DisplayObject;

				if ((item is InteractiveObject && (item as InteractiveObject).mouseEnabled && (item is Stage || _components.indexOf(item) >=0 || (item is IUIComponent)))) {
					return item as InteractiveObject;
				}else if(PARENT_SEARCH_ENABLED){
					var currentObject:DisplayObject = item.parent;
					while(currentObject && !(currentObject is Stage)){
						if (currentObject is InteractiveObject && (currentObject as InteractiveObject).mouseEnabled && (_components.indexOf(currentObject) >=0 || (currentObject is IUIComponent))) {
							return currentObject as InteractiveObject;
						}
						currentObject = currentObject.parent;
					}
				}
			}
			return _stage;
		}

		public function get customObjectFilter():Function {
			return _customObjectFilter;
		}

		public function set customObjectFilter(value:Function):void {
			_customObjectFilter = value;
		}
	}
}