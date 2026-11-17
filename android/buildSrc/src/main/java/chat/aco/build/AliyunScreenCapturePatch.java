package chat.aco.build;

import com.android.build.api.instrumentation.AsmClassVisitorFactory;
import com.android.build.api.instrumentation.ClassContext;
import com.android.build.api.instrumentation.ClassData;
import com.android.build.api.instrumentation.InstrumentationParameters;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;

/** Compatibility patch for the unregistered projection callback in AliVCSDK 7.11.0. */
public abstract class AliyunScreenCapturePatch
        implements AsmClassVisitorFactory<InstrumentationParameters.None> {
    private static final String PUSHER = "com/alivc/component/screen/b";
    private static final String CALLBACK = PUSHER + "$a";
    private static final String PROJECTION = "android/media/projection/MediaProjection";
    private static final String CALLBACK_TYPE = "L" + PROJECTION + "$Callback;";

    @Override
    public boolean isInstrumentable(ClassData data) {
        String name = data.getClassName().replace('.', '/');
        return name.equals(PUSHER) || name.equals(CALLBACK);
    }

    @Override
    public ClassVisitor createClassVisitor(ClassContext context, ClassVisitor next) {
        boolean callback = context.getCurrentClassData().getClassName()
                .replace('.', '/').equals(CALLBACK);
        return new ClassVisitor(Opcodes.ASM9, next) {
            private int patchedCalls;

            @Override
            public MethodVisitor visitMethod(int access, String name, String descriptor,
                                             String signature, String[] exceptions) {
                MethodVisitor delegate = super.visitMethod(access, name, descriptor, signature, exceptions);
                if (callback && name.equals("onStop") && descriptor.equals("()V")) {
                    patchedCalls++;
                    return new MethodVisitor(Opcodes.ASM9, delegate) {
                        @Override
                        public void visitInsn(int opcode) {
                            if (opcode == Opcodes.RETURN) {
                                // Reuse the SDK's null-safe VirtualDisplay release operation.
                                super.visitVarInsn(Opcodes.ALOAD, 0);
                                super.visitFieldInsn(Opcodes.GETFIELD, CALLBACK, "a", "L" + PUSHER + ";");
                                super.visitMethodInsn(Opcodes.INVOKEVIRTUAL, PUSHER, "e", "()V", false);
                            }
                            super.visitInsn(opcode);
                        }
                    };
                }
                return new MethodVisitor(Opcodes.ASM9, delegate) {
                    @Override
                    public void visitMethodInsn(int opcode, String owner, String method,
                                                String desc, boolean isInterface) {
                        if (!callback && owner.equals(PROJECTION) && method.equals("registerCallback")) {
                            throw new IllegalStateException("Aliyun SDK already registers its callback; review/remove 7.11.0 patch");
                        }
                        super.visitMethodInsn(opcode, owner, method, desc, isInterface);
                        if (!callback && owner.equals("android/media/projection/MediaProjectionManager")
                                && method.equals("getMediaProjection")
                                && desc.equals("(ILandroid/content/Intent;)L" + PROJECTION + ";")) {
                            patchedCalls++;
                            // Preserve the returned instance for the original SDK field assignment.
                            super.visitInsn(Opcodes.DUP);
                            super.visitVarInsn(Opcodes.ALOAD, 0);
                            super.visitFieldInsn(Opcodes.GETFIELD, PUSHER, "f", CALLBACK_TYPE);
                            super.visitTypeInsn(Opcodes.NEW, "android/os/Handler");
                            super.visitInsn(Opcodes.DUP);
                            super.visitMethodInsn(Opcodes.INVOKESTATIC, "android/os/Looper", "getMainLooper",
                                    "()Landroid/os/Looper;", false);
                            super.visitMethodInsn(Opcodes.INVOKESPECIAL, "android/os/Handler", "<init>",
                                    "(Landroid/os/Looper;)V", false);
                            super.visitMethodInsn(Opcodes.INVOKEVIRTUAL, PROJECTION, "registerCallback",
                                    "(" + CALLBACK_TYPE + "Landroid/os/Handler;)V", false);
                        }
                    }
                };
            }

            @Override
            public void visitEnd() {
                if (patchedCalls != 1) {
                    throw new IllegalStateException("Unexpected Aliyun ScreenPusher structure; review 7.11.0 patch");
                }
                super.visitEnd();
            }
        };
    }
}
