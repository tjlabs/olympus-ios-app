import Foundation

public class OlympusMathFunctions: NSObject {
    
    public override init() {
        
    }
    
    public func exponentialMovingAverage(preEMA: Double, curValue: Double, windowSize: Int) -> Double {
        let windowSizeDouble: Double = Double(windowSize)
        return preEMA*((windowSizeDouble - 1)/windowSizeDouble) + (curValue/windowSizeDouble)
    }
    
    public func calAttEMA(preAttEMA: Attitude, curAtt: Attitude, windowSize: Int) -> Attitude{
        return Attitude(
            Roll: exponentialMovingAverage(preEMA: preAttEMA.Roll, curValue: curAtt.Roll, windowSize: windowSize),
            Pitch: exponentialMovingAverage(preEMA: preAttEMA.Pitch, curValue: curAtt.Pitch, windowSize: windowSize),
            Yaw: exponentialMovingAverage(preEMA: preAttEMA.Yaw, curValue: curAtt.Yaw, windowSize: windowSize)
        )
    }
    
    public func calSensorAxisEMA(preArrayEMA: SensorAxisValue, curArray: SensorAxisValue, windowSize: Int) -> SensorAxisValue {
        return SensorAxisValue(x: exponentialMovingAverage(preEMA: preArrayEMA.x, curValue: curArray.x, windowSize: windowSize),
                               y: exponentialMovingAverage(preEMA: preArrayEMA.y, curValue: curArray.y, windowSize: windowSize),
                               z: exponentialMovingAverage(preEMA: preArrayEMA.z, curValue: curArray.z, windowSize: windowSize),
                               norm: exponentialMovingAverage(preEMA: preArrayEMA.norm, curValue: curArray.norm, windowSize: windowSize))
    }
    
    public func getRotationMatrixFromVector(rotationVector: [Double], returnSize: Int) -> [[Double]] {
        var rotationMatrix = [[Double]](repeating: [Double](repeating: 0, count: 4), count: 4)
        
        let q1: Double = rotationVector[0]
        let q2: Double = rotationVector[1]
        let q3: Double = rotationVector[2]
        let q0: Double = rotationVector[3]
        
        let sqq1 = 2 * q1 * q1
        let sqq2 = 2 * q2 * q2
        let sqq3 = 2 * q3 * q3
        let q1q2 = 2 * q1 * q2
        let q3q0 = 2 * q3 * q0
        let q1q3 = 2 * q1 * q3
        let q2q0 = 2 * q2 * q0
        let q2q3 = 2 * q2 * q3
        let q1q0 = 2 * q1 * q0
        
        if returnSize == 16 {
            rotationMatrix[0][0] = 1 - sqq2 - sqq3
            rotationMatrix[0][1] = q1q2 - q3q0
            rotationMatrix[0][2] = q1q3 + q2q0
            
            rotationMatrix[1][0] = q1q2 + q3q0
            rotationMatrix[1][1] = 1 - sqq1 - sqq3
            rotationMatrix[1][2] = q2q3 - q1q0
            
            rotationMatrix[2][0] = q1q3 - q2q0
            rotationMatrix[2][1] = q2q3 + q1q0
            rotationMatrix[2][2] = 1 - sqq1 - sqq2
            
            rotationMatrix[3][3] = 1
        } else if returnSize == 9 {
            rotationMatrix[0][0] = 1 - sqq2 - sqq3
            rotationMatrix[0][1] = q1q2 - q3q0
            rotationMatrix[0][2] = q1q3 + q2q0
            
            rotationMatrix[1][0] = q1q2 + q3q0
            rotationMatrix[1][1] = 1 - sqq1 - sqq3
            rotationMatrix[1][2] = q2q3 - q1q0
            
            rotationMatrix[2][0] = q1q3 - q2q0
            rotationMatrix[2][1] = q2q3 + q1q0
            rotationMatrix[2][2] = 1 - sqq1 - sqq2
        }
        
        return rotationMatrix
    }
    
    public func getOrientation(rotationMatrix: [[Double]]) -> [Double] {
        var orientation = [Double](repeating: 0, count: 3)
        orientation[0] = atan2(rotationMatrix[0][1], rotationMatrix[1][1])
        orientation[1] = asin(-rotationMatrix[2][1])
        orientation[2] = atan2(-rotationMatrix[2][0], rotationMatrix[2][2])
        
        return orientation
    }
    
    public func rotationXY(roll: Double, pitch: Double, gyro: [Double]) -> [Double] {
        var rotationMatrix = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        var processedGyro = [Double](repeating: 0, count: 3)
        
        let gx = gyro[0]
        let gy = gyro[1]
        let gz = gyro[2]
        
        rotationMatrix[0][0] = cos(roll)
        rotationMatrix[0][1] = 0
        rotationMatrix[0][2] = -sin(roll)

        rotationMatrix[1][0] = sin(roll) * sin(pitch)
        rotationMatrix[1][1] = 0
        rotationMatrix[1][2] = cos(roll) * sin(pitch)

        rotationMatrix[2][0] = cos(pitch) * sin(roll)
        rotationMatrix[2][1] = -sin(pitch)
        rotationMatrix[2][2] = cos(pitch) * cos(roll)
        
        processedGyro[0] =
        (gx * rotationMatrix[0][0]) + (gy * rotationMatrix[0][1]) + (gz * rotationMatrix[0][2])
        processedGyro[1] =
        (gx * rotationMatrix[1][0]) + (gy * rotationMatrix[1][1]) + (gz * rotationMatrix[1][2])
        processedGyro[2] =
        (gx * rotationMatrix[2][0]) + (gy * rotationMatrix[2][1]) + (gz * rotationMatrix[2][2])
        
        return processedGyro
    }
    
    public func calAttitudeUsingGameVector(gameVec: [Double]) -> Attitude {
        let rotationMatrix = getRotationMatrixFromVector(rotationVector: gameVec, returnSize: 9)
        let vecOrientation = getOrientation(rotationMatrix: rotationMatrix)
        
        return Attitude(Roll: vecOrientation[2], Pitch: -vecOrientation[1], Yaw: -vecOrientation[0])
    }
    
    public func calAttitudeUsingRotMatrix(rotationMatrix: [[Double]]) -> Attitude {
        let vecOrientation = getOrientation(rotationMatrix: rotationMatrix)
        
        return Attitude(Roll: vecOrientation[2], Pitch: -vecOrientation[1], Yaw: -vecOrientation[0])
    }
    
    public func l2Normalize(originalVector: [Double]) -> Double {
        var originalVectorSum: Double = 0
        for i in 0..<originalVector.count {
            originalVectorSum += (originalVector[i] * originalVector[i])
        }
        return sqrt(originalVectorSum)
    }
    
    public func transBody2Nav(att: Attitude, data: [Double]) -> [Double] {
        return rotationXY(roll: -att.Roll, pitch: -att.Pitch, gyro: data)
    }
    
    public func calSensorAxisVariance(curArray: LinkedList<SensorAxisValue>) -> SensorAxisValue {
        var bufferX = [Double]()
        var bufferY = [Double]()
        var bufferZ = [Double]()
        var bufferNorm = [Double]()
        
        let count = curArray.count
        for i in 0..<count {
            bufferX.append(curArray.node(at: i)!.value.x)
            bufferY.append(curArray.node(at: i)!.value.y)
            bufferZ.append(curArray.node(at: i)!.value.z)
            bufferNorm.append(curArray.node(at: i)!.value.norm)
        }
        
        return SensorAxisValue(x: calVariance(buffer: bufferX, bufferMean: bufferX.average),
                               y: calVariance(buffer: bufferY, bufferMean: bufferY.average),
                               z: calVariance(buffer: bufferZ, bufferMean: bufferZ.average),
                               norm: calVariance(buffer: bufferNorm, bufferMean: bufferNorm.average))
    }
    
    public func calVariance(buffer: [Double], bufferMean: Double) -> Double {
        if (buffer.count == 1) {
            return buffer[0]
        } else {
            var bufferSum: Double = 0
            
            for i in 0..<buffer.count {
                bufferSum += pow((Double(buffer[i]) - bufferMean), 2)
            }
            
            return bufferSum / Double(buffer.count - 1)
        }
    }
    
    public func calAngleOfRotation(timeInterval: Double, angularVelocity: Double) -> Double {
        return angularVelocity * Double(timeInterval) * 1e-3
    }

    public func degree2radian(degree: Double) -> Double {
        return degree * Double.pi / 180
    }

    public func radian2degree(radian: Double) -> Double {
        return radian * 180 / Double.pi
    }
    
    public func callRollUsingAcc(acc: [Double]) -> Double {
        if (acc[0] > 0 && acc[2] < 0) {
            return (atan(acc[0] / sqrt(acc[1]*acc[1] + acc[2]*acc[2])) - Double.pi)
        }
        else if (acc[2] < 0 && acc[0] < 0) {
            return (atan(acc[0] / sqrt(acc[1]*acc[1] + acc[2]*acc[2])) + Double.pi)
        }
        else {
            return -atan(acc[0] / sqrt(acc[1]*acc[1] + acc[2]*acc[2]))
        }
    }
    
    public func callPitchUsingAcc(acc: [Double]) -> Double {
        let result: Double = atan( acc[1] / sqrt(acc[0]*acc[0] + acc[2]*acc[2]) )
        
        return result
    }
}
