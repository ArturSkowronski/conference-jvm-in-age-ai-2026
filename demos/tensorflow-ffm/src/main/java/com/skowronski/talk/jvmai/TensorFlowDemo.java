package com.skowronski.talk.jvmai;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;

public final class TensorFlowDemo {
  private TensorFlowDemo() {}

  public static void main(String[] args) {
    run();
  }

  public static void run() {
    System.out.println("[TensorFlow FFM] Starting demo...");
    System.out.println("[TensorFlow FFM] Loading TensorFlow native library...");
    try (TensorFlowC tf = TensorFlowC.load()) {
      System.out.println("[TensorFlow FFM] Library loaded successfully!");
      System.out.println("[TensorFlow FFM] TensorFlow via FFM (C API)");
      System.out.println("[TensorFlow FFM] Getting version...");
      System.out.println("[TensorFlow FFM] TF_Version=" + version(tf));
      System.out.println("[TensorFlow FFM] Running computation: 1.5 + 2.25...");
      float result = addTwoScalars(tf, 1.5f, 2.25f);
      System.out.println("[TensorFlow FFM] Result: 1.5 + 2.25 = " + result);
      System.out.println("[TensorFlow FFM] Demo completed successfully!");
    }
  }

  private static String version(TensorFlowC tf) {
    try {
      MemorySegment cStr = (MemorySegment) tf.TF_Version.invokeExact();
      return tf.readUtf8Z(cStr);
    } catch (Throwable t) {
      throw new RuntimeException("TF_Version failed", t);
    }
  }

  private static float addTwoScalars(TensorFlowC tf, float a, float b) {
    try (TfStatus status = TfStatus.create(tf)) {
      MemorySegment graph = (MemorySegment) tf.TF_NewGraph.invokeExact();

      try {
        MemorySegment constA = buildConstScalar(tf, graph, status, "a", a);
        MemorySegment constB = buildConstScalar(tf, graph, status, "b", b);

        MemorySegment add = buildAdd(tf, graph, status, "add", constA, constB);

        MemorySegment sessionOptions = (MemorySegment) tf.TF_NewSessionOptions.invokeExact();
        MemorySegment session = (MemorySegment) tf.TF_NewSession.invokeExact(graph, sessionOptions, status.handle());
        status.throwIfNotOk("TF_NewSession");

        try {
          try (Arena runArena = Arena.ofConfined()) {
            MemorySegment outputs = runArena.allocate(TensorFlowC.TF_OUTPUT);
            setTfOutput(outputs, add, 0);

            MemorySegment outputTensors = runArena.allocate(ValueLayout.ADDRESS);

            tf.TF_SessionRun.invokeExact(
              session,
              MemorySegment.NULL,
              MemorySegment.NULL,
              MemorySegment.NULL,
              0,
              outputs,
              outputTensors,
              1,
              MemorySegment.NULL,
              0,
              MemorySegment.NULL,
              status.handle()
            );
            status.throwIfNotOk("TF_SessionRun");

            MemorySegment outTensor = outputTensors.get(ValueLayout.ADDRESS, 0);
            if (outTensor == MemorySegment.NULL) {
              throw new IllegalStateException("TF_SessionRun returned NULL output tensor");
            }

            try {
              MemorySegment outDataPtr = (MemorySegment) tf.TF_TensorData.invokeExact(outTensor);
              return outDataPtr.reinterpret(Float.BYTES).get(ValueLayout.JAVA_FLOAT, 0);
            } finally {
              tf.TF_DeleteTensor.invokeExact(outTensor);
            }
          }
        } finally {
          tf.TF_CloseSession.invokeExact(session, status.handle());
          status.throwIfNotOk("TF_CloseSession");
          tf.TF_DeleteSession.invokeExact(session, status.handle());
          status.throwIfNotOk("TF_DeleteSession");
          tf.TF_DeleteSessionOptions.invokeExact(sessionOptions);
        }
      } finally {
        tf.TF_DeleteGraph.invokeExact(graph);
      }
    } catch (Throwable t) {
      throw new RuntimeException("TensorFlow demo failed", t);
    }
  }

  private static MemorySegment buildConstScalar(
    TensorFlowC tf,
    MemorySegment graph,
    TfStatus status,
    String name,
    float value
  ) throws Throwable {
    MemorySegment tensor = (MemorySegment) tf.TF_AllocateTensor.invokeExact(
      TensorFlowC.TF_FLOAT,
      MemorySegment.NULL,
      0,
      (long) Float.BYTES
    );
    if (tensor == MemorySegment.NULL) {
      throw new IllegalStateException("TF_AllocateTensor returned NULL");
    }

    try {
      MemorySegment dataPtr = (MemorySegment) tf.TF_TensorData.invokeExact(tensor);
      dataPtr.reinterpret(Float.BYTES).set(ValueLayout.JAVA_FLOAT, 0, value);

      MemorySegment desc = (MemorySegment) tf.TF_NewOperation.invokeExact(
        graph,
        tf.allocateUtf8("Const"),
        tf.allocateUtf8(name)
      );
      tf.TF_SetAttrType.invokeExact(desc, tf.allocateUtf8("dtype"), TensorFlowC.TF_FLOAT);
      tf.TF_SetAttrTensor.invokeExact(desc, tf.allocateUtf8("value"), tensor, status.handle());
      status.throwIfNotOk("TF_SetAttrTensor(value)");

      MemorySegment op = (MemorySegment) tf.TF_FinishOperation.invokeExact(desc, status.handle());
      status.throwIfNotOk("TF_FinishOperation(Const)");
      return op;
    } finally {
      tf.TF_DeleteTensor.invokeExact(tensor);
    }
  }

  private static MemorySegment buildAdd(
    TensorFlowC tf,
    MemorySegment graph,
    TfStatus status,
    String name,
    MemorySegment left,
    MemorySegment right
  ) throws Throwable {
    MemorySegment desc = (MemorySegment) tf.TF_NewOperation.invokeExact(
      graph,
      tf.allocateUtf8("Add"),
      tf.allocateUtf8(name)
    );

    try (Arena arena = Arena.ofConfined()) {
      MemorySegment leftOut = arena.allocate(TensorFlowC.TF_OUTPUT);
      setTfOutput(leftOut, left, 0);
      MemorySegment rightOut = arena.allocate(TensorFlowC.TF_OUTPUT);
      setTfOutput(rightOut, right, 0);

      tf.TF_AddInput.invokeExact(desc, leftOut);
      tf.TF_AddInput.invokeExact(desc, rightOut);
    }
    tf.TF_SetAttrType.invokeExact(desc, tf.allocateUtf8("T"), TensorFlowC.TF_FLOAT);

    MemorySegment op = (MemorySegment) tf.TF_FinishOperation.invokeExact(desc, status.handle());
    status.throwIfNotOk("TF_FinishOperation(Add)");
    return op;
  }

  private static void setTfOutput(MemorySegment output, MemorySegment operation, int index) {
    output.set(ValueLayout.ADDRESS, 0, operation);
    output.set(ValueLayout.JAVA_INT, ValueLayout.ADDRESS.byteSize(), index);
  }
}
