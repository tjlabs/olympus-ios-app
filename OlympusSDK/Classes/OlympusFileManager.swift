import UIKit

public class OlympusFileManager {
    static let shared = OlympusFileManager()
    
    var sensorFileUrl: URL? = nil
    var bleFileUrl: URL? = nil

    var sensorData = [OlympusSensorData]()
    var bleTime = [Int]()
    var bleData = [[String: Double]]()
    
    init() {}
    
    private func createExportDirectory() -> URL? {
        guard let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print(getLocalTimeString() + " , (OlympusFileManager) : Unable to access document directory.")
            return nil
        }
        let exportDirectoryUrl = documentDirectoryUrl.appendingPathComponent("Export")
        if !FileManager.default.fileExists(atPath: exportDirectoryUrl.path) {
            do {
                try FileManager.default.createDirectory(at: exportDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
                print(getLocalTimeString() + " , (OlympusFileManager) : Export directory created at: \(exportDirectoryUrl)")
            } catch {
                print(getLocalTimeString() + " , (OlympusFileManager) : Error creating export directory: \(error)")
                return nil
            }
        } else {
            print(getLocalTimeString() + " , (OlympusFileManager) : Export directory already exists at: \(exportDirectoryUrl)")
        }
        
        return exportDirectoryUrl
    }
    
    public func createFiles(time: Int) {
        if let exportDir: URL = self.createExportDirectory() {
            let sensorFileName = "sensor_\(time).csv"
            let bleFileName = "ble_\(time).csv"
            sensorFileUrl = exportDir.appendingPathComponent(sensorFileName)
            bleFileUrl = exportDir.appendingPathComponent(bleFileName)
        } else {
            print(getLocalTimeString() + " , (OlympusFileManager) : Error creating export directory")
        }
    }
    
    public func writeSensorData(data: OlympusSensorData) {
        let newData = data
        sensorData.append(newData)
    }
    
    public func writeBleData(time: Int, data: [String: Double]) {
        bleTime.append(time)
        
        let newData = data
        bleData.append(newData)
    }
    
    private func saveSensorData() {
        var csvText = "time,acc_x,acc_y,acc_z,u_acc_x,u_acc_y,u_acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z,grav_x,grav_y,grav_z,att0,att1,att2,q0,q1,q2,q3,rm00,rm01,rm02,rm10,rm11,rm12,rm20,rm21,rm22,gv0,gv1,gv2,gv3,rv0,rv1,rv2,rv3,rv4,pressure\n"
        for record in sensorData {
            csvText += "\(record.time),\(record.acc[0]),\(record.acc[1]),\(record.acc[2]),\(record.userAcc[0]),\(record.userAcc[1]),\(record.userAcc[2]),\(record.gyro[0]),\(record.gyro[1]),\(record.gyro[2]),\(record.mag[0]),\(record.mag[1]),\(record.mag[2]),\(record.grav[0]),\(record.grav[1]),\(record.grav[2]),\(record.att[0]),\(record.att[1]),\(record.att[2]),\(record.quaternion[0]),\(record.quaternion[1]),\(record.quaternion[2]),\(record.quaternion[3]),\(record.rotationMatrix[0][0]),\(record.rotationMatrix[0][1]),\(record.rotationMatrix[0][2]),\(record.rotationMatrix[1][0]),\(record.rotationMatrix[1][1]),\(record.rotationMatrix[1][2]),\(record.rotationMatrix[2][0]),\(record.rotationMatrix[2][1]),\(record.rotationMatrix[2][2]),\(record.gameVector[0]),\(record.gameVector[1]),\(record.gameVector[2]),\(record.gameVector[3]),\(record.rotVector[0]),\(record.rotVector[1]),\(record.rotVector[2]),\(record.rotVector[3]),\(record.rotVector[4]),\(record.pressure[0])\n"
        }

        do {
            if let fileUrl = sensorFileUrl {
                try csvText.write(to: fileUrl, atomically: true, encoding: .utf8)
                print(getLocalTimeString() + " , (OlympusFileManager) : Data saved to \(fileUrl)")
            } else {
                print(getLocalTimeString() + " , (OlympusFileManager) : Error: sensorFileUrl is nil")
            }
        } catch {
            print(getLocalTimeString() + " , (OlympusFileManager) : Error: \(error)")
        }
        
        sensorData = [OlympusSensorData]()
    }
    
    private func saveBleData() {
        var csvText = "time,ble\n"
        for i in 0..<bleTime.count {
            csvText += "\(bleTime[i]),"
            let record = bleData[i]
            for (key, value) in record {
                csvText += "\(key):\(value),"
            }
            csvText += "\n"
        }

        do {
            if let fileUrl = bleFileUrl {
                try csvText.write(to: fileUrl, atomically: true, encoding: .utf8)
                print(getLocalTimeString() + " , (OlympusFileManager) : Data saved to \(fileUrl)")
            } else {
                print(getLocalTimeString() + " , (OlympusFileManager) : Error: bleFileUrl is nil")
            }
        } catch {
            print(getLocalTimeString() + " , (OlympusFileManager) : Error: \(error)")
        }
        
        bleTime = [Int]()
        bleData = [[String: Double]]()
    }
    
    public func saveFilesForSimulation() {
        saveBleData()
        saveSensorData()
    }
    
    public func loadFilesForSimulation() -> ([[String: Double]], [OlympusSensorData]) {
        var loadedBleData = [[String: Double]]()
        var loadedSenorData = [OlympusSensorData]()
        
        if let exportDir: URL = self.createExportDirectory() {
//            let bleFileName = "ble_start.csv"
//            let sensorFileName = "sensor_start.csv"
            let bleFileName = "ble_dr1.csv"
            let sensorFileName = "sensor_dr1.csv"
            
            let bleSimulationUrl = exportDir.appendingPathComponent(bleFileName)
            do {
                let csvData = try String(contentsOf: bleSimulationUrl)
                let bleRows = csvData.components(separatedBy: "\n")
                for row in bleRows {
                    let replacedRow = row.replacingOccurrences(of: "\r", with: "")
                    let columns = replacedRow.components(separatedBy: ",")
                    if columns[0] != "time" {
                        var bleDict = [String: Double]()
                        if (columns.count > 1) {
                            for i in 0..<columns.count {
                                if i == 0 {
                                    // time
                                } else {
                                    if (columns[i].count > 1) {
                                        let bleKeyValue = columns[i].components(separatedBy: ":")
                                        let bleKey = bleKeyValue[0]
                                        let bleValue = Double(bleKeyValue[1])!
                                        bleDict[bleKey] = bleValue
                                    }
                                }
                            }
                        }
                        
                        loadedBleData.append(bleDict)
                    }
                }
            } catch {
                print(getLocalTimeString() + " , (OlympusFileManager) : Error loading sensor file: \(error)")
            }
            

            let sensorSimulationUrl = exportDir.appendingPathComponent(sensorFileName)
            do {
                let csvData = try String(contentsOf: sensorSimulationUrl)
                let sensorRows = csvData.components(separatedBy: "\n")
                for row in sensorRows {
                    let replacedRow = row.replacingOccurrences(of: "\r", with: "")
                    let columns = replacedRow.components(separatedBy: ",")
                    if columns[0] != "time" && columns.count > 1 {
                        var olympusSensorData = OlympusSensorData()
                        olympusSensorData.time = Double(columns[0])!
                        olympusSensorData.acc = [Double(columns[1])!, Double(columns[2])!, Double(columns[3])!]
                        olympusSensorData.userAcc = [Double(columns[4])!, Double(columns[5])!, Double(columns[6])!]
                        olympusSensorData.gyro = [Double(columns[7])!, Double(columns[8])!, Double(columns[9])!]
                        olympusSensorData.mag = [Double(columns[10])!, Double(columns[11])!, Double(columns[12])!]
                        olympusSensorData.grav = [Double(columns[13])!, Double(columns[14])!, Double(columns[15])!]
                        olympusSensorData.att = [Double(columns[16])!, Double(columns[17])!, Double(columns[18])!]
                        olympusSensorData.quaternion = [Double(columns[19])!, Double(columns[20])!, Double(columns[21])!, Double(columns[22])!]
                        olympusSensorData.rotationMatrix = [[Double(columns[23])!, Double(columns[24])!, Double(columns[25])!], [Double(columns[26])!, Double(columns[27])!, Double(columns[28])!], [Double(columns[29])!, Double(columns[30])!, Double(columns[31])!]]
                        olympusSensorData.gameVector = [Float(columns[32])!, Float(columns[33])!, Float(columns[34])!, Float(columns[35])!]
                        olympusSensorData.rotVector = [Float(columns[36])!, Float(columns[37])!, Float(columns[38])!, Float(columns[39])!, Float(columns[40])!]
                        olympusSensorData.pressure = [Double(columns[41])!]
                        loadedSenorData.append(olympusSensorData)
                    }
                }
            } catch {
                print(getLocalTimeString() + " , (OlympusFileManager) : Error loading sensor file: \(error)")
            }
            
        } else {
            print(getLocalTimeString() + " , (OlympusFileManager) : Error creating export directory")
        }
        
        return (loadedBleData, loadedSenorData)
    }
}