package conf.jvm.tensorflow;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.MethodHandle;
import java.nio.file.Path;

import static java.lang.foreign.ValueLayout.ADDRESS;
import static java.lang.foreign.ValueLayout.JAVA_INT;
import static java.lang.foreign.ValueLayout.JAVA_LONG;

final class TensorFlowC implements AutoCloseable {
  static final int TF_FLOAT = 1;

  static final MemoryLayout TF_OUTPUT = MemoryLayout.structLayout(
    ADDRESS.withName("oper"),
    JAVA_INT.withName("index"),
    MemoryLayout.paddingLayout(4)
  );

  private final Arena arena;
  private final SymbolLookup lookup;
  private final Linker linker;

  final MethodHandle TF_Version;
  final MethodHandle TF_NewStatus;
  final MethodHandle TF_DeleteStatus;
  final MethodHandle TF_GetCode;
  final MethodHandle TF_Message;

  final MethodHandle TF_NewGraph;
  final MethodHandle TF_DeleteGraph;
  final MethodHandle TF_NewSessionOptions;
  final MethodHandle TF_DeleteSessionOptions;
  final MethodHandle TF_NewSession;
  final MethodHandle TF_CloseSession;
  final MethodHandle TF_DeleteSession;

  final MethodHandle TF_NewOperation;
  final MethodHandle TF_SetAttrType;
  final MethodHandle TF_SetAttrTensor;
  final MethodHandle TF_AddInput;
  final MethodHandle TF_FinishOperation;

  final MethodHandle TF_AllocateTensor;
  final MethodHandle TF_TensorData;
  final MethodHandle TF_DeleteTensor;

  final MethodHandle TF_SessionRun;

  private TensorFlowC(Arena arena, SymbolLookup lookup) {
    this.arena = arena;
    this.lookup = lookup;
    this.linker = Linker.nativeLinker();

    TF_Version = downcall("TF_Version", FunctionDescriptor.of(ADDRESS));
    TF_NewStatus = downcall("TF_NewStatus", FunctionDescriptor.of(ADDRESS));
    TF_DeleteStatus = downcall("TF_DeleteStatus", FunctionDescriptor.ofVoid(ADDRESS));
    TF_GetCode = downcall("TF_GetCode", FunctionDescriptor.of(JAVA_INT, ADDRESS));
    TF_Message = downcall("TF_Message", FunctionDescriptor.of(ADDRESS, ADDRESS));

    TF_NewGraph = downcall("TF_NewGraph", FunctionDescriptor.of(ADDRESS));
    TF_DeleteGraph = downcall("TF_DeleteGraph", FunctionDescriptor.ofVoid(ADDRESS));
    TF_NewSessionOptions = downcall("TF_NewSessionOptions", FunctionDescriptor.of(ADDRESS));
    TF_DeleteSessionOptions = downcall("TF_DeleteSessionOptions", FunctionDescriptor.ofVoid(ADDRESS));
    TF_NewSession = downcall("TF_NewSession", FunctionDescriptor.of(ADDRESS, ADDRESS, ADDRESS, ADDRESS));
    TF_CloseSession = downcall("TF_CloseSession", FunctionDescriptor.ofVoid(ADDRESS, ADDRESS));
    TF_DeleteSession = downcall("TF_DeleteSession", FunctionDescriptor.ofVoid(ADDRESS, ADDRESS));

    TF_NewOperation = downcall("TF_NewOperation", FunctionDescriptor.of(ADDRESS, ADDRESS, ADDRESS, ADDRESS));
    TF_SetAttrType = downcall("TF_SetAttrType", FunctionDescriptor.ofVoid(ADDRESS, ADDRESS, JAVA_INT));
    TF_SetAttrTensor = downcall("TF_SetAttrTensor", FunctionDescriptor.ofVoid(ADDRESS, ADDRESS, ADDRESS, ADDRESS));
    TF_AddInput = downcall("TF_AddInput", FunctionDescriptor.ofVoid(ADDRESS, TF_OUTPUT));
    TF_FinishOperation = downcall("TF_FinishOperation", FunctionDescriptor.of(ADDRESS, ADDRESS, ADDRESS));

    TF_AllocateTensor = downcall("TF_AllocateTensor", FunctionDescriptor.of(ADDRESS, JAVA_INT, ADDRESS, JAVA_INT, JAVA_LONG));
    TF_TensorData = downcall("TF_TensorData", FunctionDescriptor.of(ADDRESS, ADDRESS));
    TF_DeleteTensor = downcall("TF_DeleteTensor", FunctionDescriptor.ofVoid(ADDRESS));

    TF_SessionRun = downcall(
      "TF_SessionRun",
      FunctionDescriptor.ofVoid(
        ADDRESS, // session
        ADDRESS, // run_options (TF_Buffer*)
        ADDRESS, // inputs (TF_Output*)
        ADDRESS, // input_values (TF_Tensor* const*)
        JAVA_INT, // ninputs
        ADDRESS, // outputs (TF_Output*)
        ADDRESS, // output_values (TF_Tensor**)
        JAVA_INT, // noutputs
        ADDRESS, // target_opers (TF_Operation* const*)
        JAVA_INT, // ntargets
        ADDRESS, // run_metadata (TF_Buffer*)
        ADDRESS // status
      )
    );
  }

  static TensorFlowC load() {
    Path home = TensorFlowNative.resolveHome();
    TensorFlowNative.Libraries libs = TensorFlowNative.resolveLibraries(home);

    Arena arena = Arena.ofShared();
    SymbolLookup lookup = SymbolLookup.loaderLookup().or(Linker.nativeLinker().defaultLookup());

    if (libs.framework() != null) {
      lookup = SymbolLookup.libraryLookup(libs.framework(), arena).or(lookup);
    }
    lookup = SymbolLookup.libraryLookup(libs.tensorflow(), arena).or(lookup);

    return new TensorFlowC(arena, lookup);
  }

  MemorySegment allocateUtf8(String value) {
    return arena.allocateFrom(value);
  }

  String readUtf8Z(MemorySegment address) {
    if (address == MemorySegment.NULL) return null;
    return address.reinterpret(Long.MAX_VALUE).getString(0);
  }

  private MethodHandle downcall(String symbol, FunctionDescriptor descriptor) {
    MemorySegment addr = lookup.find(symbol)
      .orElseThrow(() -> new UnsatisfiedLinkError("Missing TensorFlow symbol: " + symbol));
    return linker.downcallHandle(addr, descriptor);
  }

  @Override
  public void close() {
    arena.close();
  }
}
