package com.skowronski.talk.jvmai;

import java.lang.foreign.MemorySegment;

final class TfStatus implements AutoCloseable {
  private final TensorFlowC tf;
  private final MemorySegment handle;

  private TfStatus(TensorFlowC tf, MemorySegment handle) {
    this.tf = tf;
    this.handle = handle;
  }

  static TfStatus create(TensorFlowC tf) {
    try {
      return new TfStatus(tf, (MemorySegment) tf.TF_NewStatus.invokeExact());
    } catch (Throwable t) {
      throw new RuntimeException("TF_NewStatus failed", t);
    }
  }

  MemorySegment handle() {
    return handle;
  }

  void throwIfNotOk(String action) {
    int code;
    try {
      code = (int) tf.TF_GetCode.invokeExact(handle);
    } catch (Throwable t) {
      throw new RuntimeException("TF_GetCode failed", t);
    }

    if (code == 0) return;

    String msg;
    try {
      MemorySegment cMsg = (MemorySegment) tf.TF_Message.invokeExact(handle);
      msg = tf.readUtf8Z(cMsg);
    } catch (Throwable t) {
      msg = "<failed to read TF_Status message: " + t.getClass().getSimpleName() + ">";
    }

    throw new IllegalStateException(action + " failed (TF code=" + code + "): " + msg);
  }

  @Override
  public void close() {
    try {
      tf.TF_DeleteStatus.invokeExact(handle);
    } catch (Throwable t) {
      throw new RuntimeException("TF_DeleteStatus failed", t);
    }
  }
}
