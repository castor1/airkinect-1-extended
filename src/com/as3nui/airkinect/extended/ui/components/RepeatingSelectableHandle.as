/**
 *
 * User: Ross
 * Date: 11/19/11
 * Time: 4:49 PM
 */
package com.as3nui.airkinect.extended.ui.components {
	import com.as3nui.airkinect.extended.ui.display.BaseSelectionTimer;
	import com.as3nui.airkinect.extended.ui.events.UIEvent;

	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.utils.getTimer;

	public class RepeatingSelectableHandle extends Handle {

		protected var _selectionTimer:BaseSelectionTimer;
		protected var _selectionStartTimer:int;
		protected var _selectionDelay:uint;

		//Repeat Delay timer
		protected var _repeatTimer:BaseSelectionTimer;
		protected var _repeatDelay:uint;
		protected var _repeatStartTime:Number;


		public function RepeatingSelectableHandle(icon:DisplayObject, selectionTimer:BaseSelectionTimer, repeatTimer:BaseSelectionTimer = null, selectedIcon:DisplayObject = null, disabledIcon:DisplayObject = null, selectionDelay:uint = 1, repeatDelay:uint = 1, capturePadding:Number = .45, minPull:Number = .1, maxPull:Number = 1) {
			super(icon, selectedIcon, disabledIcon, capturePadding, minPull, maxPull);
			_selectionDelay = selectionDelay;
			_selectionTimer = selectionTimer;

			_repeatTimer = repeatTimer;
			_repeatDelay = repeatDelay;
			_repeatStartTime = NaN;
		}

		override protected function onRemovedFromStage():void {
			super.onRemovedFromStage();
			this.removeEventListener(Event.ENTER_FRAME, onSelectionTimeUpdate);
		}

		override protected function onHandleCapture():void {
			super.onHandleCapture();
			addSelectionTimer();
			startSelectionTimer();
		}

		private function addSelectionTimer():void {
			this.addChild(_selectionTimer);
			_selectionTimer.x = centerPoint.x - (_selectionTimer.width / 2);
			_selectionTimer.y = centerPoint.y - (_selectionTimer.height / 2);
		}

		private function startSelectionTimer():void {
			_selectionTimer.onProgress(0);
			_selectionStartTimer = getTimer();
			this.addEventListener(Event.ENTER_FRAME, onSelectionTimeUpdate);
		}

		override protected function onHandleRelease():void {
			super.onHandleRelease();
			if (this.contains(_selectionTimer)) this.removeChild(_selectionTimer);
			if (this.contains(_repeatTimer)) this.removeChild(_repeatTimer);
			this.removeEventListener(Event.ENTER_FRAME, onSelectionTimeUpdate);

			_repeatStartTime = NaN;
		}

		protected function onSelectionTimeUpdate(event:Event):void {
			var progress:Number;

			if (!(isNaN(_repeatStartTime))) {
				progress = (getTimer() - _repeatStartTime) / (_repeatDelay * 1000);
				if (_repeatTimer) _repeatTimer.onProgress(progress);
				if (progress >= 1) {
					if (this.contains(_repeatTimer)) this.removeChild(_repeatTimer);
					if (!this.contains(_selectionTimer)) addSelectionTimer();

					_repeatStartTime = NaN;
					_selectionStartTimer = getTimer();
				}
			} else {
				progress = (getTimer() - _selectionStartTimer) / (_selectionDelay * 1000);
				_selectionTimer.onProgress(progress);
				if (progress >= 1) onSelected();
			}
		}

		protected function onSelected():void {
			if (_repeatDelay > 0) {
				_repeatStartTime = getTimer();
				if (_repeatTimer && _repeatDelay > 0) {
					if (this.contains(_selectionTimer)) this.removeChild(_selectionTimer);

					//Repeat Timer
					this.addChild(_repeatTimer);
					_repeatTimer.x = centerPoint.x - (_repeatTimer.width / 2);
					_repeatTimer.y = centerPoint.y - (_repeatTimer.height / 2);
				}
			}

			var globalPosition:Point = this.localToGlobal(centerPoint);
			this.dispatchEvent(new UIEvent(UIEvent.SELECTED, _cursor, centerPoint.x, centerPoint.y, globalPosition.x, globalPosition.y));
		}

		//----------------------------------
		// Selection Delay
		//----------------------------------
		public function get selectionDelay():uint {
			return _selectionDelay;
		}

		public function set selectionDelay(value:uint):void {
			_selectionDelay = value;
		}
	}
}