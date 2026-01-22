package demo.babylon;

import java.lang.module.ModuleDescriptor;
import java.util.stream.Collectors;

public class RuntimeCheck {
    public static void main(String[] args) {
        System.out.println("=== JDK Runtime Information ===");
        System.out.println("Java Version:    " + System.getProperty("java.version"));
        System.out.println("Java Vendor:     " + System.getProperty("java.vendor"));
        System.out.println("Runtime Name:    " + System.getProperty("java.runtime.name"));
        System.out.println("Runtime Version: " + System.getProperty("java.runtime.version"));
        System.out.println("OS:              " + System.getProperty("os.name") + " (" + System.getProperty("os.arch") + ")");
        
        System.out.println("\n=== Loaded Modules ===");
        String modules = ModuleLayer.boot().modules().stream()
                .map(Module::getName)
                .sorted()
                .collect(Collectors.joining(", "));
        System.out.println(modules);
        
        System.out.println("\n=== Code Reflection Check ===");
        boolean hasCodeReflection = ModuleLayer.boot().findModule("jdk.incubator.code").isPresent() || 
                                     ModuleLayer.boot().findModule("java.lang.reflect.code").isPresent();
        System.out.println("Code Reflection Module Present: " + hasCodeReflection);
    }
}

