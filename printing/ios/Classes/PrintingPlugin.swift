/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Flutter
import Foundation

@objc
public class PrintingPlugin: NSObject, FlutterPlugin {
    private static var instance: PrintingPlugin?
    private var channel: FlutterMethodChannel
    public var jobs = [UInt32: PrintJob]()

    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        PrintingPlugin.instance = self
    }

    @objc
    public static func setDocument(job: UInt32, doc: UnsafePointer<UInt8>, size: UInt64) {
        instance?.jobs[job]?.setDocument(Data(bytes: doc, count: Int(size)))
    }

    @objc
    public static func setError(job: UInt32, message: UnsafePointer<CChar>) {
        instance?.jobs[job]?.cancelJob(String(cString: message))
    }

    /// Entry point
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "net.nfet.printing", binaryMessenger: registrar.messenger())
        let instance = PrintingPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Flutter method handlers
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterMethodNotImplemented)
            return
        }
        if call.method == "printPdf" {
            guard let name = args["name"] as? String,
                  let width = args["width"] as? NSNumber,
                  let height = args["height"] as? NSNumber,
                  let marginLeft = args["marginLeft"] as? NSNumber,
                  let marginTop = args["marginTop"] as? NSNumber,
                  let marginRight = args["marginRight"] as? NSNumber,
                  let marginBottom = args["marginBottom"] as? NSNumber,
                  let jobIndex = args["job"] as? Int,
                  let dynamic = args["dynamic"] as? Bool,
                  let forceCustomPrintPaper = args["forceCustomPrintPaper"] as? Bool else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            let printer = args["printer"] as? String
            let printJob = PrintJob(printing: self, index: jobIndex)

            let outputType: UIPrintInfo.OutputType
            switch args["outputType"] as? Int ?? 0 {
            case 0:
                outputType = UIPrintInfo.OutputType.general
            case 1:
                outputType = UIPrintInfo.OutputType.photo
            case 2:
                outputType = UIPrintInfo.OutputType.grayscale
            case 3:
                outputType = UIPrintInfo.OutputType.photoGrayscale
            default:
                outputType = UIPrintInfo.OutputType.general
            }

            jobs[UInt32(jobIndex)] = printJob
            printJob.printPdf(name: name,
                              withPageSize: CGSize(
                                  width: CGFloat(width.floatValue),
                                  height: CGFloat(height.floatValue)
                              ),
                              andMargin: CGRect(
                                  x: CGFloat(marginLeft.floatValue),
                                  y: CGFloat(marginTop.floatValue),
                                  width: CGFloat(width.floatValue) - CGFloat(marginRight.floatValue) - CGFloat(marginLeft.floatValue),
                                  height: CGFloat(height.floatValue) - CGFloat(marginBottom.floatValue) - CGFloat(marginTop.floatValue)
                              ),
                              withPrinter: printer,
                              dynamically: dynamic,
                              outputType: outputType,
                              forceCustomPrintPaper: forceCustomPrintPaper)
            result(NSNumber(value: 1))
        } else if call.method == "sharePdf" {
            guard let object = args["doc"] as? FlutterStandardTypedData,
                  let name = args["name"] as? String else {
                result(FlutterMethodNotImplemented)
                return
            }
            PrintJob.sharePdf(
                data: object.data,
                withSourceRect: CGRect(
                    x: CGFloat((args["x"] as? NSNumber)?.floatValue ?? 0.0),
                    y: CGFloat((args["y"] as? NSNumber)?.floatValue ?? 0.0),
                    width: CGFloat((args["w"] as? NSNumber)?.floatValue ?? 0.0),
                    height: CGFloat((args["h"] as? NSNumber)?.floatValue ?? 0.0)
                ),
                andName: name,
                subject: args["subject"] as? String,
                body: args["body"] as? String
            )
            result(NSNumber(value: 1))
        } else if call.method == "convertHtml" {
            guard let html = args["html"] as? String,
                  let jobIndex = args["job"] as? Int else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            let width = CGFloat((args["width"] as? NSNumber)?.floatValue ?? 0.0)
            let height = CGFloat((args["height"] as? NSNumber)?.floatValue ?? 0.0)
            let marginLeft = CGFloat((args["marginLeft"] as? NSNumber)?.floatValue ?? 0.0)
            let marginTop = CGFloat((args["marginTop"] as? NSNumber)?.floatValue ?? 0.0)
            let marginRight = CGFloat((args["marginRight"] as? NSNumber)?.floatValue ?? 0.0)
            let marginBottom = CGFloat((args["marginBottom"] as? NSNumber)?.floatValue ?? 0.0)
            let printJob = PrintJob(printing: self, index: jobIndex)

            printJob.convertHtml(
                html,
                withPageSize: CGRect(
                    x: 0.0,
                    y: 0.0,
                    width: width,
                    height: height
                ),
                andMargin: CGRect(
                    x: marginLeft,
                    y: marginTop,
                    width: width - marginRight - marginLeft,
                    height: height - marginBottom - marginTop
                ),
                andBaseUrl: args["baseUrl"] as? String == nil ? nil : URL(string: args["baseUrl"] as! String)
            )
            result(NSNumber(value: 1))
        } else if call.method == "pickPrinter" {
            PrintJob.pickPrinter(result: result, withSourceRect: CGRect(
                x: CGFloat((args["x"] as? NSNumber)?.floatValue ?? 0.0),
                y: CGFloat((args["y"] as? NSNumber)?.floatValue ?? 0.0),
                width: CGFloat((args["w"] as? NSNumber)?.floatValue ?? 0.0),
                height: CGFloat((args["h"] as? NSNumber)?.floatValue ?? 0.0)
            ))
        } else if call.method == "printingInfo" {
            result(PrintJob.printingInfo())
        } else if call.method == "rasterPdf" {
            guard let doc = args["doc"] as? FlutterStandardTypedData,
                  let scale = args["scale"] as? NSNumber,
                  let jobIndex = args["job"] as? Int else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            let pages = args["pages"] as? [Int]
            let printJob = PrintJob(printing: self, index: jobIndex)
            printJob.rasterPdf(data: doc.data,
                               pages: pages,
                               scale: CGFloat(scale.floatValue))
            result(NSNumber(value: 1))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Request the Pdf document from flutter
    public func onLayout(printJob: PrintJob, width: CGFloat, height: CGFloat, marginLeft: CGFloat, marginTop: CGFloat, marginRight: CGFloat, marginBottom: CGFloat) {
        let arg = [
            "width": width,
            "height": height,
            "marginLeft": marginLeft,
            "marginTop": marginTop,
            "marginRight": marginRight,
            "marginBottom": marginBottom,
            "job": printJob.index,
        ] as [String: Any]

        channel.invokeMethod("onLayout", arguments: arg)
    }

    /// send completion status to flutter
    public func onCompleted(printJob: PrintJob, completed: Bool, error: NSString?) {
        let data: NSDictionary = [
            "completed": completed,
            "error": error as Any,
            "job": printJob.index,
        ]
        channel.invokeMethod("onCompleted", arguments: data)
        jobs.removeValue(forKey: UInt32(printJob.index))
    }

    /// send html to pdf data result to flutter
    public func onHtmlRendered(printJob: PrintJob, pdfData: Data) {
        let data: NSDictionary = [
            "doc": FlutterStandardTypedData(bytes: pdfData),
            "job": printJob.index,
        ]
        channel.invokeMethod("onHtmlRendered", arguments: data)
    }

    /// send html to pdf conversion error to flutter
    public func onHtmlError(printJob: PrintJob, error: String) {
        let data: NSDictionary = [
            "error": error,
            "job": printJob.index,
        ]
        channel.invokeMethod("onHtmlError", arguments: data)
    }

    /// send pdf to raster data result to flutter
    public func onPageRasterized(printJob: PrintJob, imageData: Data, width: Int, height: Int) {
        let data: NSDictionary = [
            "image": FlutterStandardTypedData(bytes: imageData),
            "width": width,
            "height": height,
            "job": printJob.index,
        ]
        channel.invokeMethod("onPageRasterized", arguments: data)
    }

    public func onPageRasterEnd(printJob: PrintJob, error: String?) {
        let data: NSDictionary = [
            "job": printJob.index,
            "error": error as Any,
        ]
        channel.invokeMethod("onPageRasterEnd", arguments: data)
    }
}
