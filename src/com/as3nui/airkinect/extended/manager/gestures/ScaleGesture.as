/*
 * Copyright 2012 AS3NUI
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

package com.as3nui.airkinect.extended.manager.gestures {
	import com.as3nui.airkinect.extended.manager.regions.Region;
	import com.as3nui.airkinect.extended.manager.skeleton.DeltaResult;
	import com.as3nui.airkinect.extended.manager.skeleton.ExtendedSkeleton;

	import flash.geom.Vector3D;

	import flash.utils.Dictionary;
	import flash.utils.getTimer;

	/**
	 * Swipe is defined as two joints moving away from each other (OUT) or towards eachother (IN).
	 */
	public class ScaleGesture extends AbstractKinectGesture {

		/**
		 * Constant for Scale Outwards
		 */
		public static const SCALE_OUT:String	= "out";
		/**
		 * Constant for Scale Inwards
		 */
		public static const SCALE_IN:String		= "in";

		/**
		 * Minimum delay (milliseoncds) allowed between Scale Dispatches
		 */
		public static var DISPATCH_DELAY:uint = 1000;
		public static var LAST_DISPATCHED_LOOKUP:Dictionary = new Dictionary();

		/**
		 * Current Scale Type detected
		 */
		protected var _currentScaleType:String;
		/**
		 * Left Side joint used for detection
		 */
		protected var _leftJointID:uint;
		/**
		 * Right Side joint used for detection
		 */
		protected var _rightJointID:uint;

		/**
		 * Steps in history to check
		 */
		protected var _historySteps:int = 7;

		/**
		 * Collection of joints used in this gesture
		 */
		protected var _jointss:Vector.<uint>;

		//Result from the time the gesture began
		private var _startLeftDeltaResult:DeltaResult;
		private var _startRightDeltaResult:DeltaResult;
		private var _startDistance:Vector3D;

		//Current Results from the Gesture
		private var _currentLeftDeltaResult:DeltaResult;
		private var _currentRightDeltaResult:DeltaResult;
		private var _currentDistance:Vector3D;

		/**
		 * Scale gesture supports 2 directions (IN and OUT)
		 * @param skeleton			Skeleton to track scale on
		 * @param leftJointID		Left Joint for Scale Gesture
		 * @param rightJointID		Right Joint for Scale Gesture
		 * @param regions			Regions to force start of gesture into
		 */
		public function ScaleGesture(skeleton:ExtendedSkeleton, leftJointID:uint,  rightJointID:uint,  regions:Vector.<Region> = null) {
			super(skeleton, regions);
			_leftJointID = leftJointID;
			_rightJointID = rightJointID;
			_jointss = new <uint>[_leftJointID, _rightJointID];
		}

		/**
		 * Dispose this gesture from memory
		 */
		override public function dispose():void {
			LAST_DISPATCHED_LOOKUP[_skeleton.trackingID] = null;
			delete LAST_DISPATCHED_LOOKUP[_skeleton.trackingID];
			super.dispose();
		}

		/**
		 * Called from the gesture manager, this function should not be called manually.
		 */
		override public function update():void {
			super.update();

			//If this gesture is complete or canceled, reset it.
			if (_currentState == GestureState.GESTURE_COMPLETE || _currentState == GestureState.GESTURE_CANCELED) {
				resetGesture();
				return;
			}

			//Delta of the left joint
			_currentLeftDeltaResult = _skeleton.calculateDelta(_leftJointID, _historySteps);
			//Delta of the Right joint
			_currentRightDeltaResult= _skeleton.calculateDelta(_rightJointID, _historySteps);
			//Distance between the deltas
			_currentDistance = _currentRightDeltaResult.delta.subtract(_currentLeftDeltaResult.delta);

			//If the current start is idle
			if(_currentState == GestureState.GESTURE_IDLE) {
				//Check thresholds to determine start of a scale outward
				if(_currentLeftDeltaResult.delta.x <= -.15 && _currentRightDeltaResult.delta.x >= .15) {
					_currentScaleType = SCALE_OUT;
					beginGesture();
				//Check thresholds to determin a start of a scale inward
				}else if(_currentLeftDeltaResult.delta.x >= .15 && _currentRightDeltaResult.delta.x <= -.15) {
					_currentScaleType = SCALE_IN;
					beginGesture();
				}
			//Gesture is started or being processed
			} else if(_currentScaleType && _currentState == GestureState.GESTURE_STARTED || _currentState == GestureState.GESTURE_PROGRESS){
				//If this is a outward scale and the thresholds are not hit, continue processing.
				if(_currentScaleType == SCALE_OUT && (_currentLeftDeltaResult.delta.x <= -.1 && _currentRightDeltaResult.delta.x >= .1)) {
					progressGesture();
				//If this is a inward scale and the thresholds are not hit, continue processing
				}else if(_currentScaleType == SCALE_IN && (_currentLeftDeltaResult.delta.x >= .1 && _currentRightDeltaResult.delta.x <= -.1)) {
					progressGesture();
				//Gesture is success
				}else{
					completeGesture();
				}
			}
		}

		override protected function beginGesture():void {
			updateJointsStartedOutOfRegion(_jointss, _historySteps);

			_startLeftDeltaResult = _currentLeftDeltaResult;
			_startRightDeltaResult = _currentRightDeltaResult;
			_startDistance = _currentDistance;
//			trace("Started");
			//trace("Out of Region :: " + _jointStartedOutOfRegion);
			super.beginGesture();
		}

		override protected function progressGesture():void {
//			trace("Progress");
			super.progressGesture();
		}

		override protected function cancelGesture():void {
//			trace("Canceled");
			super.cancelGesture();
		}

		override protected function completeGesture():void {
			if (_jointStartedOutOfRegion) {
//				trace("Gesture complete, but started out of region");
				cancelGesture();
				return;
			}

			if(LAST_DISPATCHED_LOOKUP[_skeleton.trackingID] == null) LAST_DISPATCHED_LOOKUP[_skeleton.trackingID] = 0;
			if(LAST_DISPATCHED_LOOKUP[_skeleton.trackingID]  + DISPATCH_DELAY > getTimer()){
//				trace("Swipe Attempted too soon after last Scale, canceled, wait " + ((LAST_DISPATCHED_LOOKUP[_skeleton.trackingID]  + DISPATCH_DELAY) - getTimer()) +"ms");
				cancelGesture();
				return;
			}

			LAST_DISPATCHED_LOOKUP[_skeleton.trackingID]  = getTimer();
			super.completeGesture();
		}

		override protected function resetGesture():void {
//			trace("Reset");
			super.resetGesture();
		}

		public function get currentScaleType():String {
			return _currentScaleType;
		}

		public function get startLeftDeltaResult():DeltaResult {
			return _startLeftDeltaResult;
		}

		public function get startRightDeltaResult():DeltaResult {
			return _startRightDeltaResult;
		}

		public function get currentLeftDeltaResult():DeltaResult {
			return _currentLeftDeltaResult;
		}

		public function get currentRightDeltaResult():DeltaResult {
			return _currentRightDeltaResult;
		}
	}
}