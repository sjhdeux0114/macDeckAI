import Foundation
import Metal
let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let candidate = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
func dispatch(_ data: Data) -> DispatchData { data.withUnsafeBytes { DispatchData(bytes: $0) } }
guard let device = MTLCreateSystemDefaultDevice() else { fatalError("No Metal device") }
let oldLibrary = try device.makeLibrary(data: dispatch(original))
let newLibrary = try device.makeLibrary(data: dispatch(candidate))
guard Set(oldLibrary.functionNames) == Set(newLibrary.functionNames) else { fatalError("Function names changed") }
print("PASS matching library functions:",newLibrary.functionNames.count)
if candidate.count <= original.count {
 var padded = candidate; padded.append(Data(repeating:0,count:original.count-candidate.count))
 _ = try device.makeLibrary(data:dispatch(padded))
 print("PASS original-size padded library loads:",candidate.count,"<=",original.count)
}
let name = "gs_draw_arguments_marshal"
let desc = MTLRenderPipelineDescriptor()
desc.vertexFunction = newLibrary.makeFunction(name:name)
desc.isRasterizationEnabled = false
desc.colorAttachments[0].pixelFormat = .rgba8Unorm
let pipeline = try device.makeRenderPipelineState(descriptor:desc)
let draws = device.makeBuffer(length:16,options:.storageModeShared)!
let outputs = device.makeBuffer(length:24,options:.storageModeShared)!
let tasks = device.makeBuffer(length:64,options:.storageModeShared)!
let input = draws.contents().bindMemory(to:UInt32.self,capacity:4)
input[0]=0;input[1]=1;input[2]=33;input[3]=1
memset(outputs.contents(),0x7f,24)
for i in 0..<2 {
 let p = tasks.contents().advanced(by:i*32)
 p.storeBytes(of:draws.gpuAddress+UInt64(i*8),as:UInt64.self)
 p.advanced(by:8).storeBytes(of:outputs.gpuAddress+UInt64(i*12),as:UInt64.self)
 p.advanced(by:16).storeBytes(of:UInt64(1024),as:UInt64.self)
 p.advanced(by:24).storeBytes(of:UInt32(32),as:UInt32.self)
 p.advanced(by:28).storeBytes(of:UInt32(i==1 ? 1:0),as:UInt32.self)
}
let queue=device.makeCommandQueue()!
let command=queue.makeCommandBuffer()!
let pass=MTLRenderPassDescriptor();pass.renderTargetWidth=1;pass.renderTargetHeight=1
let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:1,height:1,mipmapped:false)
textureDesc.usage = .renderTarget
pass.colorAttachments[0].texture = device.makeTexture(descriptor:textureDesc)
pass.colorAttachments[0].loadAction = .dontCare
pass.colorAttachments[0].storeAction = .dontCare
let encoder=command.makeRenderCommandEncoder(descriptor:pass)!
encoder.setRenderPipelineState(pipeline)
encoder.setVertexBuffer(tasks,offset:0,index:0)
encoder.useResource(draws,usage:.read,stages:.vertex)
encoder.useResource(outputs,usage:.write,stages:.vertex)
encoder.drawPrimitives(type:.point,vertexStart:0,vertexCount:1)
encoder.endEncoding();command.commit();command.waitUntilCompleted()
guard command.status == .completed else { print("GPU failed:", String(describing:command.error)); exit(1) }
let result=outputs.contents().bindMemory(to:UInt32.self,capacity:6)
let values=(0..<6).map{result[$0]}
guard values == [0,0,0,2,1,1] else { fatalError("Wrong dispatch: \(values)") }
print("PASS actual Metal GS batch: zero draw skipped; second task executed:",values)
// TS control-point count zero must not divide by zero; second task still executes.
input[0]=33;input[1]=1;input[2]=33;input[3]=1
memset(outputs.contents(),0x7f,24)
for i in 0..<2 {
 let p=tasks.contents().advanced(by:i*32)
 p.advanced(by:24).storeBytes(of:UInt16(i==0 ? 0:3),as:UInt16.self)
 p.advanced(by:26).storeBytes(of:UInt16(4),as:UInt16.self)
}
desc.vertexFunction=newLibrary.makeFunction(name:"ts_draw_arguments_marshal")
let tsPipeline=try device.makeRenderPipelineState(descriptor:desc)
let tsCommand=queue.makeCommandBuffer()!
let tsEncoder=tsCommand.makeRenderCommandEncoder(descriptor:pass)!
tsEncoder.setRenderPipelineState(tsPipeline)
tsEncoder.setVertexBuffer(tasks,offset:0,index:0)
tsEncoder.useResource(draws,usage:.read,stages:.vertex)
tsEncoder.useResource(outputs,usage:.write,stages:.vertex)
tsEncoder.drawPrimitives(type:.point,vertexStart:0,vertexCount:1)
tsEncoder.endEncoding();tsCommand.commit();tsCommand.waitUntilCompleted()
guard tsCommand.status == .completed else { print("TS GPU failed:",String(describing:tsCommand.error));exit(1) }
let tsValues=(0..<6).map{result[$0]}
guard tsValues == [0,0,0,3,1,1] else { print("Wrong TS dispatch:",tsValues);exit(1) }
print("PASS actual Metal TS batch: zero control points skipped; second task executed:",tsValues)
